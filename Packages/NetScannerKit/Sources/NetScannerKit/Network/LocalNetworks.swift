import Darwin
import SystemConfiguration

/// An IPv4 network this Mac is attached to, offered as a scan target so
/// people rarely have to type a subnet.
public struct LocalNetwork: Identifiable, Hashable, Sendable {
    /// The network itself, e.g. `192.168.1.0/24`.
    public let subnet: Subnet
    /// This Mac's own address on it.
    public let address: IPv4
    /// BSD interface name, e.g. `en0`.
    public let interfaceName: String
    /// What System Settings calls the interface, e.g. "Wi-Fi".
    public let displayName: String
    /// Whether this interface carries the default route.
    public let isPrimary: Bool

    public var id: String { "\(interfaceName) \(subnet)" }
}

public enum LocalNetworks {
    /// The attached IPv4 networks worth scanning, primary interface
    /// first. Skips loopback, link-local and point-to-point links (VPN
    /// tunnels), which have no neighbors to discover.
    public static func current() -> [LocalNetwork] {
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0, let first else { return [] }
        defer { freeifaddrs(first) }

        let names = interfaceDisplayNames()
        let primary = primaryInterfaceName()
        var networks: [LocalNetwork] = []

        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(entry.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_RUNNING != 0,
                flags & IFF_LOOPBACK == 0, flags & IFF_POINTOPOINT == 0,
                let address = ipv4(entry.pointee.ifa_addr),
                let mask = ipv4(entry.pointee.ifa_netmask),
                !address.isLinkLocal, !address.isLoopback
            else { continue }

            let name = String(cString: entry.pointee.ifa_name)
            let prefix = mask.rawValue.nonzeroBitCount
            let network = IPv4(rawValue: address.rawValue & mask.rawValue)
            networks.append(
                LocalNetwork(
                    subnet: Subnet(address: network, prefixLength: prefix),
                    address: address,
                    interfaceName: name,
                    displayName: names[name] ?? name,
                    isPrimary: name == primary))
        }

        return networks.sorted {
            ($0.isPrimary ? 0 : 1, $0.interfaceName, $0.address)
                < ($1.isPrimary ? 0 : 1, $1.interfaceName, $1.address)
        }
    }

    private static func ipv4(_ socketAddress: UnsafeMutablePointer<sockaddr>?) -> IPv4? {
        guard let socketAddress, socketAddress.pointee.sa_family == sa_family_t(AF_INET) else {
            return nil
        }
        return socketAddress.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
            IPv4(rawValue: UInt32(bigEndian: $0.pointee.sin_addr.s_addr))
        }
    }

    /// BSD name to localized display name ("en0" to "Wi-Fi").
    private static func interfaceDisplayNames() -> [String: String] {
        guard let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else {
            return [:]
        }
        var names: [String: String] = [:]
        for interface in interfaces {
            if let bsdName = SCNetworkInterfaceGetBSDName(interface) as String?,
                let displayName = SCNetworkInterfaceGetLocalizedDisplayName(interface) as String?
            {
                names[bsdName] = displayName
            }
        }
        return names
    }

    /// The interface carrying the default IPv4 route, e.g. "en0".
    private static func primaryInterfaceName() -> String? {
        let key = "State:/Network/Global/IPv4" as CFString
        guard let store = SCDynamicStoreCreate(nil, "NetScanner" as CFString, nil, nil),
            let global = SCDynamicStoreCopyValue(store, key) as? [String: Any]
        else { return nil }
        return global["PrimaryInterface"] as? String
    }
}
