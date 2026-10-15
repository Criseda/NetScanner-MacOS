import Foundation
import NetScannerKit

/// State of the Discovery screen: the form, the hosts found, and how
/// they are sorted, filtered and selected.
@Observable
final class DiscoveryModel {
    let activity = ScanActivity()

    // MARK: Form

    var subnetText: String {
        didSet { UserDefaults.standard.set(subnetText, forKey: Keys.subnet) }
    }

    var method: DiscoveryOptions.Method {
        didSet { UserDefaults.standard.set(method.rawValue, forKey: Keys.method) }
    }

    var identifyDevices: Bool {
        didSet { UserDefaults.standard.set(identifyDevices, forKey: Keys.identifyDevices) }
    }

    /// The parsed form, or why it cannot be scanned.
    var validatedSubnet: Result<Subnet, InputError> {
        Result { () throws(InputError) in try Subnet(validating: subnetText) }
    }

    /// Set when a scan was requested for a subnet large enough that the
    /// user should confirm it first; the view asks.
    var needsLargeScanConfirmation = false

    /// The subnet of the scan that produced the current results.
    private(set) var scannedSubnet: Subnet?

    // MARK: Results

    /// Every host found by the last scan, by address.
    private var hostsByIP: [IPv4: DiscoveredHost] = [:]

    /// Hosts matching the search, in table order. Recomputed only when
    /// the hosts, the search or the sort change, never per render.
    private(set) var visibleHosts: [DiscoveredHost] = []

    var hostCount: Int { hostsByIP.count }

    var searchText = "" {
        didSet { refreshVisibleHosts() }
    }

    var sortOrder: [HostComparator] = [HostComparator(.ip)] {
        didSet { refreshVisibleHosts() }
    }

    var selection: Set<IPv4> = []

    var selectedHosts: [DiscoveredHost] {
        visibleHosts.filter { selection.contains($0.ip) }
    }

    func host(_ ip: IPv4) -> DiscoveredHost? { hostsByIP[ip] }

    // MARK: Lifecycle

    init(defaultSubnet: Subnet?) {
        let defaults = UserDefaults.standard
        subnetText = defaults.string(forKey: Keys.subnet) ?? defaultSubnet?.description ?? ""
        method = defaults.string(forKey: Keys.method).flatMap(DiscoveryOptions.Method.init) ?? .standard
        identifyDevices = defaults.object(forKey: Keys.identifyDevices) as? Bool ?? true
    }

    /// Starts a scan of the subnet in the form, replacing the results.
    /// `knownPorts` fills in open ports from earlier port scans this
    /// session, so they survive a rediscovery.
    func scan(
        with engine: ScanEngine, confirmed: Bool = false,
        knownPorts: @escaping (IPv4) -> [OpenPort]?
    ) {
        guard case .success(let subnet) = validatedSubnet else { return }
        guard confirmed || subnet.usableHostCount <= Subnet.confirmationHostCount else {
            needsLargeScanConfirmation = true
            return
        }
        hostsByIP = [:]
        selection = []
        scannedSubnet = subnet
        refreshVisibleHosts()

        let options = DiscoveryOptions(
            subnet: subnet, method: method, identifyDevices: identifyDevices)
        activity.run(engine.scan(.discovery(options))) { [weak self] batch in
            self?.apply(batch, knownPorts: knownPorts)
        }
    }

    func stop() {
        activity.stop()
    }

    /// Records a finished port scan on the host it was for, if listed.
    func record(openPorts: [OpenPort], for ip: IPv4) {
        guard hostsByIP[ip] != nil else { return }
        hostsByIP[ip]?.openPorts = openPorts
        refreshVisibleHosts()
    }

    // MARK: - Private

    private func apply(_ batch: [EngineEvent], knownPorts: (IPv4) -> [OpenPort]?) {
        var changed = false
        for event in batch {
            switch event {
            case .hostFound(let ip, let source) where hostsByIP[ip] == nil:
                hostsByIP[ip] = DiscoveredHost(ip: ip, source: source, openPorts: knownPorts(ip))
                changed = true
            case .hostDetail(let detail):
                hostsByIP[detail.ip]?.apply(detail)
                changed = true
            default:
                continue
            }
        }
        if changed { refreshVisibleHosts() }
    }

    private func refreshVisibleHosts() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = query.isEmpty ? Array(hostsByIP.values) : hostsByIP.values.filter { $0.matches(query) }
        visibleHosts = matching.sorted(using: sortOrder)
    }

    private enum Keys {
        static let subnet = "discovery.subnet"
        static let method = "discovery.method"
        static let identifyDevices = "discovery.identifyDevices"
    }
}
