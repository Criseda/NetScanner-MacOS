import Foundation

/// An IPv4 network in CIDR form, e.g. `192.168.1.0/24`: what `ns -s`
/// sweeps.
public struct Subnet: Hashable, Sendable {
    /// The address as typed. The engine accepts any address inside the
    /// network (`192.168.1.7/24` scans the whole /24), so it is passed
    /// through unchanged rather than normalized behind the user's back.
    public let address: IPv4
    public let prefixLength: Int

    /// The most hosts the app lets one discovery scan probe: a /16.
    /// Larger sweeps take minutes and flood the network; the engine can
    /// still do them from the command line.
    public static let maxHostCount = 65_534

    /// Above this many hosts, the app asks before scanning.
    public static let confirmationHostCount = 4_096

    public init(address: IPv4, prefixLength: Int) {
        precondition((0...32).contains(prefixLength), "prefix length out of range")
        self.address = address
        self.prefixLength = prefixLength
    }

    /// Parses and validates CIDR text, including the size limit.
    public init(validating text: String) throws(InputError) {
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).split(
            separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, let address = IPv4(parts[0]) else { throw .invalidSubnet }
        guard parts[1].allSatisfy(\.isASCIIDigit), let prefix = Int(parts[1]),
            (0...32).contains(prefix)
        else { throw .invalidPrefixLength }

        self.init(address: address, prefixLength: prefix)
        guard usableHostCount <= Self.maxHostCount else {
            throw .subnetTooLarge(hostCount: usableHostCount)
        }
    }

    public var mask: UInt32 {
        prefixLength == 0 ? 0 : UInt32.max << (32 - prefixLength)
    }

    public var networkAddress: IPv4 { IPv4(rawValue: address.rawValue & mask) }

    public var broadcastAddress: IPv4 { IPv4(rawValue: address.rawValue | ~mask) }

    /// How many addresses `ns` probes. Mirrors the engine's
    /// `usableHosts`: network and broadcast are skipped, except in /31
    /// and /32, which have neither.
    public var usableHostCount: Int {
        let size = 1 << (32 - prefixLength)
        return prefixLength >= 31 ? size : size - 2
    }

    public func contains(_ ip: IPv4) -> Bool {
        ip.rawValue & mask == networkAddress.rawValue
    }
}

extension Subnet: CustomStringConvertible {
    public var description: String { "\(address)/\(prefixLength)" }
}
