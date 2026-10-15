import Foundation

/// The TCP ports `ns -p` probes, both ends included.
public struct PortRange: Hashable, Sendable {
    public let lowerBound: UInt16
    public let upperBound: UInt16

    /// Ports 1-1024: the well-known services, about a second on a LAN.
    public static let wellKnown = PortRange(1, 1024)
    /// Every TCP port.
    public static let all = PortRange(1, 65_535)

    /// Accepts the ends in either order, as the engine does.
    public init(_ a: UInt16, _ b: UInt16) {
        precondition(a > 0 && b > 0, "port 0 is not scannable")
        lowerBound = min(a, b)
        upperBound = max(a, b)
    }

    /// Parses `80` or `1-1024` (spaces around the dash allowed).
    public init(validating text: String) throws(InputError) {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard (1...2).contains(parts.count),
            parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isASCIIDigit) })
        else { throw .invalidPortRange }

        // Parse as Int first so 70000 reads "out of range", not "invalid".
        let numbers = parts.compactMap { Int($0.prefix(6)) }
        guard numbers.count == parts.count, numbers.allSatisfy((1...65_535).contains) else {
            throw .portOutOfRange
        }
        self.init(UInt16(numbers[0]), UInt16(numbers[numbers.count - 1]))
    }

    public var count: Int { Int(upperBound) - Int(lowerBound) + 1 }

    /// The form `ns -p` takes: always two ends.
    var engineArgument: String { "\(lowerBound)-\(upperBound)" }
}

extension PortRange: CustomStringConvertible {
    public var description: String {
        lowerBound == upperBound ? "\(lowerBound)" : "\(lowerBound)-\(upperBound)"
    }
}

/// A fixed wait per probe for `ns -p --timeout`. Without one, the
/// engine learns the wait from the host's own answers (100-500 ms),
/// which is the right choice almost always.
public struct ProbeTimeout: Hashable, Sendable {
    public let milliseconds: Int

    public static let validRange = 1...60_000

    public init?(milliseconds: Int) {
        guard Self.validRange.contains(milliseconds) else { return nil }
        self.milliseconds = milliseconds
    }

    /// Empty text means automatic (nil); anything else must be 1-60000.
    public static func parse(_ text: String) throws(InputError) -> ProbeTimeout? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        guard trimmed.allSatisfy(\.isASCIIDigit), let value = Int(trimmed.prefix(6)),
            let timeout = ProbeTimeout(milliseconds: value)
        else { throw .invalidTimeout }
        return timeout
    }
}
