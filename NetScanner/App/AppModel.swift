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
        guard isEngineUsable, !activeActivity.isRunning else { return false }
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
    func startDiscovery(confirmed: Bool = false) {
        discovery.scan(with: engine, confirmed: confirmed) { [weak self] ip in
            self?.portHistory[ip]
        }
    }

    func startPortScan() {
        portScan.scan(with: engine) { [weak self] host, ports in
            self?.portHistory[host] = ports
            self?.discovery.record(openPorts: ports, for: host)
        }
    }

    /// Switches to Port Scan and scans `host` with the default ports.
    func scanPorts(of host: IPv4) {
        section = .portScan
        portScan.hostText = host.description
        startPortScan()
    }
}
