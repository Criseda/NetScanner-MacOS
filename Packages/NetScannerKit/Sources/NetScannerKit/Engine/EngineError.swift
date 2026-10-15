import Foundation

/// Why a scan could not run or finish.
public enum EngineError: LocalizedError, Equatable, Sendable {
    /// The `ns` binary is not where the app expects it.
    case missing(path: String)
    /// `ns` could not be started at all.
    case launchFailed(reason: String)
    /// The engine rejected the request (`{"type":"error"}`).
    case rejected(message: String)
    /// The engine exited abnormally without saying why on stdout.
    case failed(status: Int32, diagnostics: String)

    public var errorDescription: String? {
        switch self {
        case .missing:
            String(localized: "The scan engine is missing from the app.", bundle: .module)
        case .launchFailed:
            String(localized: "The scan engine could not be started.", bundle: .module)
        case .rejected(let message):
            message
        case .failed(let status, _):
            String(localized: "The scan engine stopped unexpectedly (status \(status)).", bundle: .module)
        }
    }

    public var failureReason: String? {
        switch self {
        case .missing(let path):
            String(localized: "Expected it at \(path). Reinstall NetScanner.", bundle: .module)
        case .launchFailed(let reason):
            reason
        case .rejected:
            nil
        case .failed(_, let diagnostics):
            diagnostics.isEmpty ? nil : diagnostics
        }
    }
}
