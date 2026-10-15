import Foundation
import NetScannerKit

/// State of the Port Scan screen: the form, the open ports found, and
/// how they are sorted and filtered.
@Observable
final class PortScanModel {
    let activity = ScanActivity()

    // MARK: Form

    var hostText = ""
    var rangeText = UserDefaults.standard.string(forKey: PortScanDefaults.rangeKey) ?? PortScanDefaults.range

    /// The parsed form, or the first reason it cannot be scanned.
    var validatedOptions: Result<PortScanOptions, InputError> {
        Result { () throws(InputError) in
            guard let host = IPv4(hostText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw .invalidAddress
            }
            return PortScanOptions(
                host: host,
                ports: try PortRange(validating: rangeText),
                timeout: try ProbeTimeout.parse(PortScanDefaults.timeoutText))
        }
    }

    /// The host of the scan that produced the current results.
    private(set) var scannedHost: IPv4?

    // MARK: Results

    private var portsByNumber: [UInt16: OpenPort] = [:]

    private(set) var visiblePorts: [OpenPort] = []

    var portCount: Int { portsByNumber.count }

    var searchText = "" {
        didSet { refreshVisiblePorts() }
    }

    var sortOrder: [OpenPortComparator] = [OpenPortComparator(.port)] {
        didSet { refreshVisiblePorts() }
    }

    var selection: Set<UInt16> = []

    var selectedPorts: [OpenPort] {
        visiblePorts.filter { selection.contains($0.port) }
    }

    // MARK: Lifecycle

    /// Starts a scan of the form's host and ports, replacing the results.
    /// `completion` gets every open port once the scan finishes (not
    /// when it is stopped or fails), so other screens can show them.
    func scan(with engine: ScanEngine, completion: @escaping (IPv4, [OpenPort]) -> Void) {
        guard case .success(let options) = validatedOptions else { return }
        portsByNumber = [:]
        selection = []
        scannedHost = options.host
        refreshVisiblePorts()

        activity.run(engine.scan(.portScan(options))) { [weak self] batch in
            guard let self else { return }
            apply(batch)
            if batch.contains(where: \.isPortScanSummary) {
                completion(options.host, portsByNumber.values.sorted { $0.port < $1.port })
            }
        }
    }

    func stop() {
        activity.stop()
    }

    // MARK: - Private

    private func apply(_ batch: [EngineEvent]) {
        var changed = false
        for event in batch {
            switch event {
            case .portFound(let port):
                portsByNumber[port.port] = port
                changed = true
            case .portScanFinished(let openPorts, _):
                // Every port already streamed with its name; this only
                // fills gaps, should a line ever be missed.
                for number in openPorts where portsByNumber[number] == nil {
                    portsByNumber[number] = OpenPort(port: number)
                    changed = true
                }
            default:
                continue
            }
        }
        if changed { refreshVisiblePorts() }
    }

    private func refreshVisiblePorts() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = query.isEmpty ? Array(portsByNumber.values) : portsByNumber.values.filter { $0.matches(query) }
        visiblePorts = matching.sorted(using: sortOrder)
    }
}

/// Defaults for new port scans, set in Settings.
enum PortScanDefaults {
    static let rangeKey = "portScan.defaultRange"
    static let timeoutKey = "portScan.defaultTimeout"
    static let range = PortRange.wellKnown.description

    /// Empty means automatic: the engine learns the wait per host.
    static var timeoutText: String {
        UserDefaults.standard.string(forKey: timeoutKey) ?? ""
    }
}

extension EngineEvent {
    fileprivate var isPortScanSummary: Bool {
        if case .portScanFinished = self { true } else { false }
    }
}
