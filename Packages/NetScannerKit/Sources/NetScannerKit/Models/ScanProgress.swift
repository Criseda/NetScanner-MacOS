import Foundation

/// A stage of a scan, from the engine's `progress.phase`. Phases arrive
/// in this order, and each counts from zero to its own total.
public enum ScanPhase: Hashable, Sendable {
    /// `ns -s`: probing every address in the subnet.
    case sweep
    /// `ns -s`: confirming quiet hosts found in the ARP table.
    case arp
    /// `ns -s --resolve`: looking up names and manufacturers.
    case identify
    /// `ns -p`: probing ports.
    case ports
    case other(String)

    init(engineValue: String) {
        self =
            switch engineValue {
            case "sweep": .sweep
            case "arp": .arp
            case "identify": .identify
            case "ports": .ports
            default: .other(engineValue)
            }
    }

    /// What the status line says while the phase runs.
    public var label: String {
        switch self {
        case .sweep: String(localized: "Sweeping", bundle: .module)
        case .arp: String(localized: "Checking quiet hosts", bundle: .module)
        case .identify: String(localized: "Identifying devices", bundle: .module)
        case .ports: String(localized: "Probing ports", bundle: .module)
        case .other(let id): id.prefix(1).uppercased() + id.dropFirst()
        }
    }
}

/// How far the current phase has got.
public struct ScanProgress: Hashable, Sendable {
    public let phase: ScanPhase
    public let done: Int
    public let total: Int

    public init(phase: ScanPhase, done: Int, total: Int) {
        self.phase = phase
        self.total = max(total, 1)
        self.done = min(max(done, 0), self.total)
    }

    /// 0...1, for a progress view.
    public var fraction: Double { Double(done) / Double(total) }

    /// "42%" for sweeps (big, uninteresting counts), "3 of 9" where the
    /// counts are small and mean something (hosts).
    public var countText: String {
        switch phase {
        case .sweep, .ports:
            fraction.formatted(.percent.precision(.fractionLength(0)).rounded(rule: .down))
        default:
            String(localized: "\(done) of \(total)", bundle: .module)
        }
    }
}
