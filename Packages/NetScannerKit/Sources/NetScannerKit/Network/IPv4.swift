/// An IPv4 address, stored as its 32-bit value.
///
/// Storing the number rather than the text makes addresses cheap to
/// hash, compare and sort numerically (`192.168.1.9` before
/// `192.168.1.10`), which is what every host table needs.
public struct IPv4: RawRepresentable, Hashable, Comparable, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public init(_ a: UInt8, _ b: UInt8, _ c: UInt8, _ d: UInt8) {
        rawValue = UInt32(a) << 24 | UInt32(b) << 16 | UInt32(c) << 8 | UInt32(d)
    }

    /// Parses a strict dotted quad, the only form the engine accepts.
    ///
    /// `inet_aton` style parsing is deliberately not used: it takes
    /// shorthand (`192.168.1` means `192.168.0.1`) and hex or octal
    /// octets, which `ns` rejects after the form said they were fine.
    public init?(_ text: some StringProtocol) {
        var value: UInt32 = 0
        var octetCount = 0
        for part in text.split(separator: ".", omittingEmptySubsequences: false) {
            guard part.count >= 1, part.count <= 3, part.allSatisfy(\.isASCIIDigit),
                let octet = UInt8(part)
            else { return nil }
            value = value << 8 | UInt32(octet)
            octetCount += 1
        }
        guard octetCount == 4 else { return nil }
        rawValue = value
    }

    public var octets: (UInt8, UInt8, UInt8, UInt8) {
        (
            UInt8(truncatingIfNeeded: rawValue >> 24),
            UInt8(truncatingIfNeeded: rawValue >> 16),
            UInt8(truncatingIfNeeded: rawValue >> 8),
            UInt8(truncatingIfNeeded: rawValue)
        )
    }

    /// Link-local (169.254.0.0/16): self-assigned when DHCP failed,
    /// rarely worth scanning.
    public var isLinkLocal: Bool { rawValue >> 16 == 0xA9FE }

    public var isLoopback: Bool { rawValue >> 24 == 127 }

    public static func < (lhs: IPv4, rhs: IPv4) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension IPv4: CustomStringConvertible {
    public var description: String {
        let (a, b, c, d) = octets
        return "\(a).\(b).\(c).\(d)"
    }
}

extension Character {
    /// `isNumber` also accepts other scripts' digits and fractions;
    /// addresses and ports only ever use 0-9.
    var isASCIIDigit: Bool { isASCII && isWholeNumber }
}
