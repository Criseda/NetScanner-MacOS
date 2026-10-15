/// How a host was first seen, from the engine's `host.source`.
///
/// The engine adds sources over time, so an unknown one is kept by its
/// own name rather than dropped or passed off as TCP.
public enum HostSource: Hashable, Sendable {
    /// Answered (or refused) a TCP connect.
    case tcp
    /// Answered the multicast DNS service query.
    case mdns
    /// Answered the SSDP (UPnP) search.
    case ssdp
    /// Quiet on TCP, but present in the kernel's ARP table.
    case arp
    /// Answered an ICMP echo (`--ping` scans).
    case ping
    case other(String)

    public init(engineValue: String?) {
        switch engineValue {
        case nil, "", "tcp": self = .tcp
        case "mdns": self = .mdns
        case "ssdp": self = .ssdp
        case "arp": self = .arp
        case "ping": self = .ping
        case let value?: self = .other(value)
        }
    }

    /// Short label for tables: protocol names are not translated.
    public var label: String {
        switch self {
        case .tcp: "TCP"
        case .mdns: "mDNS"
        case .ssdp: "SSDP"
        case .arp: "ARP"
        case .ping: "Ping"
        case .other(let value): value.uppercased()
        }
    }
}
