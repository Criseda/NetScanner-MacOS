import Foundation
import Network
import Synchronization

/// Whether macOS lets this app (and the `ns` it starts) reach devices on
/// the local network.
public enum LocalNetworkAccess: Equatable, Sendable {
    case granted
    case denied
    /// The user has not answered the prompt in time, or the check could
    /// not tell. Scans still run; they may find only this Mac.
    case undetermined
}

/// Asks for, and reports, Local Network access.
///
/// macOS has no API to query this permission. Its prompt appears the
/// first time the app touches the local network, and until the user
/// answers, that traffic fails silently. If the first touch is a scan,
/// the scan finds only this Mac. So the app checks once at launch,
/// before any scan, the way Apple's TN3179 suggests: it advertises a
/// private Bonjour service and browses for it. Seeing its own service
/// proves multicast works (granted); the browser failing with
/// `PolicyDenied` means the user said no. While the prompt is open,
/// neither happens, so the check simply waits for the answer.
///
/// The service type must be listed under `NSBonjourServices` in the
/// app's Info.plist.
public enum LocalNetworkPermission {
    public static let serviceType = "_netscanner._tcp"

    public static func check(timeout: Duration = .seconds(60)) async -> LocalNetworkAccess {
        let probe = Probe()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                probe.start(timeout: timeout) { continuation.resume(returning: $0) }
            }
        } onCancel: {
            probe.finish(.undetermined)
        }
    }
}

/// One advertise-and-browse round. Network framework calls back on
/// `queue`; the outcome is delivered exactly once.
private final class Probe: Sendable {
    private let queue = DispatchQueue(label: "io.github.criseda.netscanner.local-network-probe")
    private let name = UUID().uuidString
    private let state = Mutex<State>(State())

    private struct State {
        var listener: NWListener?
        var browser: NWBrowser?
        var completion: (@Sendable (LocalNetworkAccess) -> Void)?
    }

    func start(timeout: Duration, completion: @escaping @Sendable (LocalNetworkAccess) -> Void) {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = false

        let listener: NWListener
        do {
            listener = try NWListener(using: parameters)
        } catch {
            completion(.undetermined)
            return
        }
        listener.service = NWListener.Service(name: name, type: LocalNetworkPermission.serviceType)
        // Nothing ever connects; the listener exists only to advertise.
        listener.newConnectionHandler = { $0.cancel() }
        listener.stateUpdateHandler = { [self] state in
            if case .failed = state { finish(.undetermined) }
        }

        let browser = NWBrowser(
            for: .bonjour(type: LocalNetworkPermission.serviceType, domain: nil),
            using: parameters)
        browser.stateUpdateHandler = { [self] state in
            switch state {
            case .waiting(let error) where Self.isPolicyDenial(error):
                finish(.denied)
            case .failed(let error):
                finish(Self.isPolicyDenial(error) ? .denied : .undetermined)
            default:
                // Other waits are transient (no network yet); keep going
                // until the timeout.
                break
            }
        }
        browser.browseResultsChangedHandler = { [self] results, _ in
            let foundOwnService = results.contains { result in
                if case .service(let serviceName, _, _, _) = result.endpoint {
                    return serviceName == name
                }
                return false
            }
            if foundOwnService { finish(.granted) }
        }

        state.withLock {
            $0.listener = listener
            $0.browser = browser
            $0.completion = completion
        }
        listener.start(queue: queue)
        browser.start(queue: queue)
        queue.asyncAfter(deadline: .now() + timeout.timeInterval) { [self] in
            finish(.undetermined)
        }
    }

    func finish(_ access: LocalNetworkAccess) {
        let (completion, listener, browser) = state.withLock { state in
            defer { state = State() }
            return (state.completion, state.listener, state.browser)
        }
        listener?.cancel()
        browser?.cancel()
        completion?(access)
    }

    private static func isPolicyDenial(_ error: NWError) -> Bool {
        if case .dns(let code) = error { return code == DNSServiceErrorType(kDNSServiceErr_PolicyDenied) }
        return false
    }
}

extension Duration {
    fileprivate var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}
