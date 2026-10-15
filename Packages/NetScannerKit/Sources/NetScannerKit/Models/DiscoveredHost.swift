import Foundation

/// One live host found by `ns -s`.
///
/// The host arrives first with only its address and how it was seen;
/// hostname, MAC and manufacturer follow after the sweep when device
/// identification is on. Open ports are filled in when the user port
/// scans the host.
public struct DiscoveredHost: Identifiable, Hashable, Sendable {
    public let ip: IPv4
    public let source: HostSource
    public let foundAt: Date
    public var hostname: String?
    public var macAddress: String?
    public var vendor: String?
    /// Open ports from the latest port scan; nil when never scanned.
    public var openPorts: [OpenPort]?

    public var id: IPv4 { ip }

    public init(
        ip: IPv4, source: HostSource, foundAt: Date = .now,
        hostname: String? = nil, macAddress: String? = nil, vendor: String? = nil,
        openPorts: [OpenPort]? = nil
    ) {
        self.ip = ip
        self.source = source
        self.foundAt = foundAt
        self.hostname = hostname
        self.macAddress = macAddress
        self.vendor = vendor
        self.openPorts = openPorts
    }

    /// What a person calls this device: its name when known, else the IP.
    public var displayName: String { hostname ?? ip.description }

    public mutating func apply(_ detail: HostDetail) {
        hostname = detail.hostname
        macAddress = detail.macAddress
        vendor = detail.vendor
    }

    /// Everything searchable about the host, for the search field.
    public func matches(_ query: String) -> Bool {
        ip.description.contains(query)
            || [hostname, macAddress, vendor, source.label].contains {
                $0?.localizedStandardContains(query) ?? false
            }
            || (openPorts?.contains { $0.matches(query) } ?? false)
    }
}

/// Identification for one host (`host_detail`), reported after the
/// sweep. Nil fields were not resolved or not requested.
public struct HostDetail: Hashable, Sendable {
    public let ip: IPv4
    public let hostname: String?
    public let macAddress: String?
    public let vendor: String?

    public init(ip: IPv4, hostname: String?, macAddress: String?, vendor: String?) {
        self.ip = ip
        self.hostname = hostname
        self.macAddress = macAddress
        self.vendor = vendor
    }
}
