import Foundation

/// Sorts hosts by one table column.
///
/// Blank cells (no name, no MAC, never port scanned) sort last in both
/// directions, and ties fall back to the IP address, so unnamed hosts
/// stay in address order at the bottom instead of being shuffled.
public struct HostComparator: SortComparator, Hashable, Sendable {
    public enum Field: Hashable, Sendable {
        case ip, name, vendor, macAddress, source, openPorts, foundAt
    }

    public var field: Field
    public var order: SortOrder

    public init(_ field: Field, order: SortOrder = .forward) {
        self.field = field
        self.order = order
    }

    public func compare(_ lhs: DiscoveredHost, _ rhs: DiscoveredHost) -> ComparisonResult {
        let primary: ComparisonResult? =
            switch field {
            case .ip: compareValues(lhs.ip, rhs.ip)
            case .name: compareText(lhs.hostname, rhs.hostname)
            case .vendor: compareText(lhs.vendor, rhs.vendor)
            case .macAddress: compareText(lhs.macAddress, rhs.macAddress)
            case .source: compareText(lhs.source.label, rhs.source.label)
            case .openPorts: compareValues(lhs.openPorts?.count, rhs.openPorts?.count)
            case .foundAt: compareValues(lhs.foundAt, rhs.foundAt)
            }
        if let primary, primary != .orderedSame { return primary }
        return compareValues(lhs.ip, rhs.ip, ordered: false) ?? .orderedSame
    }

    private func compareText(_ lhs: String?, _ rhs: String?) -> ComparisonResult? {
        orderBlanksLast(lhs.flatMap(nonBlank), rhs.flatMap(nonBlank)) {
            $0.localizedStandardCompare($1)
        }
    }

    /// `ordered: false` ignores the sort direction, for tie-breaks.
    private func compareValues<Value: Comparable>(
        _ lhs: Value?, _ rhs: Value?, ordered: Bool = true
    ) -> ComparisonResult? {
        orderBlanksLast(lhs, rhs, ordered: ordered) { a, b in
            a < b ? .orderedAscending : a > b ? .orderedDescending : .orderedSame
        }
    }

    private func orderBlanksLast<Value>(
        _ lhs: Value?, _ rhs: Value?, ordered: Bool = true,
        _ compare: (Value, Value) -> ComparisonResult
    ) -> ComparisonResult? {
        switch (lhs, rhs) {
        case (nil, nil): return nil
        case (nil, _): return .orderedDescending
        case (_, nil): return .orderedAscending
        case let (a?, b?):
            let result = compare(a, b)
            return ordered && order == .reverse ? result.reversed : result
        }
    }
}

/// Sorts open ports by one table column; blanks last, ties by port.
public struct OpenPortComparator: SortComparator, Hashable, Sendable {
    public enum Field: Hashable, Sendable {
        case port, service, category, iana, description
    }

    public var field: Field
    public var order: SortOrder

    public init(_ field: Field, order: SortOrder = .forward) {
        self.field = field
        self.order = order
    }

    public func compare(_ lhs: OpenPort, _ rhs: OpenPort) -> ComparisonResult {
        let byPort = comparePorts(lhs.port, rhs.port)
        let text: (OpenPort) -> String? =
            switch field {
            case .port: { _ in nil }
            case .service: \.service
            case .category: { $0.category?.label }
            case .iana: \.iana
            case .description: \.distinctDescription
            }
        if field == .port { return order == .reverse ? byPort.reversed : byPort }

        switch (text(lhs).flatMap(nonBlank), text(rhs).flatMap(nonBlank)) {
        case (nil, nil): return byPort
        case (nil, _): return .orderedDescending
        case (_, nil): return .orderedAscending
        case let (a?, b?):
            let result = a.localizedStandardCompare(b)
            if result == .orderedSame { return byPort }
            return order == .reverse ? result.reversed : result
        }
    }

    private func comparePorts(_ a: UInt16, _ b: UInt16) -> ComparisonResult {
        a < b ? .orderedAscending : a > b ? .orderedDescending : .orderedSame
    }
}

private func nonBlank(_ text: String) -> String? {
    text.isEmpty ? nil : text
}

extension ComparisonResult {
    fileprivate var reversed: ComparisonResult {
        switch self {
        case .orderedAscending: .orderedDescending
        case .orderedDescending: .orderedAscending
        case .orderedSame: .orderedSame
        }
    }
}
