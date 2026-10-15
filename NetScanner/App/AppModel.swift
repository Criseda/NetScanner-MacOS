import Foundation
import NetScannerKit

/// App-wide state: the engine, the attached networks, and the two scan
/// screens, plus the hand-offs between them.
@Observable
final class AppModel {
    enum Section: String, CaseIterable, Identifiable {
        case discovery, portScan

        var id: Self { self }

        var title: LocalizedStringResource {
            switch self {
            case .discovery: "Discovery"
            case .portScan: "Port Scan"
            }
        }

        var symbolName: String {
            switch self {
            case .discovery: "network"
            case .portScan: "door.left.hand.open"
            }
        }
    }

    enum EngineStatus: Equatable {
        case checking
        case ready(version: String)
        case unavailable(EngineError)
    }

    let engine: ScanEngine
    private(set) var engineStatus: EngineStatus = .checking
    private(set) var localNetworks: [LocalNetwork]

    var section: Section = .discovery

    let discovery: DiscoveryModel
    let portScan = PortScanModel()

    /// Local Network access, from the check at launch; nil until macOS
    /// (or the user, at the prompt) has answered.
    private(set) var localNetworkAccess: LocalNetworkAccess?
    private var localNetworkCheck: Task<LocalNetworkAccess, Never>?

    /// A scan was requested while the Local Network check is still
    /// waiting for the user; it starts once they answer.
    private(set) var isWaitingForLocalNetwork = false

    /// Open ports from every finished port scan this session, by host.
    private var portHistory: [IPv4: [OpenPort]] = [:]

    init(engine: ScanEngine = .bundled) {
        self.engine = engine
        let networks = LocalNetworks.current()
        localNetworks = networks
        discovery = DiscoveryModel(defaultSubnet: networks.first?.subnet)
    }

    /// Checks that the bundled engine runs, once at launch.
    func checkEngine() async {
        do {
            engineStatus = .ready(version: try await engine.version())
        } catch let error as EngineError {
            engineStatus = .unavailable(error)
        } catch {
            engineStatus = .unavailable(.launchFailed(reason: error.localizedDescription))
        }
    }

    /// Asks for Local Network access before any scan does, so the
    /// system prompt appears at launch rather than silently swallowing
    /// the first scan. Run again whenever access is not yet granted and
    /// the app becomes active: the user may have changed it in System
    /// Settings meanwhile.
    func checkLocalNetworkAccess() {
        guard localNetworkCheck == nil, localNetworkAccess != .granted else { return }
        let check = Task { await LocalNetworkPermission.check() }
        localNetworkCheck = check
        Task {
            localNetworkAccess = await check.value
            localNetworkCheck = nil
        }
    }

    func refreshLocalNetworks() {
        localNetworks = LocalNetworks.current()
    }

    // MARK: Scans

    var isEngineUsable: Bool {
        if case .unavailable = engineStatus { false } else { true }
    }

    var activeActivity: ScanActivity {
        switch section {
        case .discovery: discovery.activity
        case .portScan: portScan.activity
        }
    }

    var canStartScan: Bool {
        guard isEngineUsable, !activeActivity.isRunning, !isWaitingForLocalNetwork else {
            return false
        }
        switch section {
        case .discovery: return (try? discovery.validatedSubnet.get()) != nil
        case .portScan: return (try? portScan.validatedOptions.get()) != nil
        }
    }

    /// Starts a scan on the visible screen (⌘R).
    func startScan() {
        guard canStartScan else { return }
        switch section {
        case .discovery: startDiscovery()
        case .portScan: startPortScan()
        }
    }

    /// Stops the scan on the visible screen (⌘.).
    func stopScan() {
        activeActivity.stop()
    }

    /// `confirmed` skips the question asked before very large sweeps.
    /// Discovery is pointless without Local Network access, so it does
    /// not start when access is denied; the screen explains why.
    func startDiscovery(confirmed: Bool = false) {
        afterLocalNetworkCheck(skipIfDenied: true) { [self] in
            discovery.scan(with: engine, confirmed: confirmed) { [weak self] ip in
                self?.portHistory[ip]
            }
        }
    }

    /// Port scans run even without Local Network access: the host may be
    /// beyond the local network.
    func startPortScan() {
        afterLocalNetworkCheck(skipIfDenied: false) { [self] in
            portScan.scan(with: engine) { [weak self] host, ports in
                self?.portHistory[host] = ports
                self?.discovery.record(openPorts: ports, for: host)
            }
        }
    }

    /// Runs `scan` now, or once the pending Local Network check answers.
    private func afterLocalNetworkCheck(skipIfDenied: Bool, _ scan: @escaping () -> Void) {
        guard let check = localNetworkCheck else {
            if !(skipIfDenied && localNetworkAccess == .denied) { scan() }
            return
        }
        isWaitingForLocalNetwork = true
        Task {
            let access = await check.value
            isWaitingForLocalNetwork = false
            if !(skipIfDenied && access == .denied) { scan() }
        }
    }

    /// Switches to Port Scan and scans `host` with the default ports.
    func scanPorts(of host: IPv4) {
        section = .portScan
        portScan.hostText = host.description
        startPortScan()
    }
}
