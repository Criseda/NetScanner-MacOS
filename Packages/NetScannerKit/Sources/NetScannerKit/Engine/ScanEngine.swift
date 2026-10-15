import Foundation

/// The `ns` scan engine, run as a child process.
///
/// The engine is the single source of truth for scanning: this type only
/// launches it with `--json`, turns its output into typed events as they
/// arrive, answers its requests for the ARP table (which macOS may hide
/// from it but not from the app), and stops it when the consumer stops
/// listening.
public struct ScanEngine: Sendable {
    /// Reads the ARP table for the engine (`--neighbor-table=parent`).
    public typealias NeighborTableReader = @Sendable () throws(NeighborTableError) -> [NeighborEntry]

    public let executableURL: URL
    let readNeighborTable: NeighborTableReader

    /// `readNeighborTable` answers the engine's requests for the ARP
    /// table; it is replaceable so tests need no real network.
    public init(
        executableURL: URL, readNeighborTable: @escaping NeighborTableReader = NeighborTable.read
    ) {
        self.executableURL = executableURL
        self.readNeighborTable = readNeighborTable
    }

    /// Runs a scan and streams its events.
    ///
    /// Events come in batches, one per read from the engine's output:
    /// the engine often prints dozens of lines at once, and applying
    /// them to the UI together costs one update instead of dozens.
    ///
    /// Cancelling the consuming task (or dropping the stream) terminates
    /// the engine. The stream finishes normally when the scan completes
    /// or is cancelled, and throws an ``EngineError`` otherwise.
    public func scan(_ request: ScanRequest) -> AsyncThrowingStream<[EngineEvent], any Error> {
        AsyncThrowingStream { continuation in
            guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
                continuation.finish(throwing: EngineError.missing(path: executableURL.path))
                return
            }
            let run = EngineRun(
                executableURL: executableURL, arguments: request.arguments,
                readNeighborTable: readNeighborTable, continuation: continuation)
            continuation.onTermination = { termination in
                if case .cancelled = termination { run.cancel() }
            }
            run.start()
        }
    }

    /// The engine's version, e.g. `v1.6.0`.
    public func version() async throws -> String {
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw EngineError.missing(path: executableURL.path)
        }
        let process = Process()
        let output = Pipe()
        process.executableURL = executableURL
        process.arguments = ["--version"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        // The output is one short line, far below the pipe buffer, so it
        // is safe to read only once the process has exited.
        let status: Int32 = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(
                    throwing: EngineError.launchFailed(reason: error.localizedDescription))
            }
        }
        let data = (try? output.fileHandleForReading.readToEnd()) ?? Data()
        let version = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard status == 0, !version.isEmpty else {
            throw EngineError.failed(status: status, diagnostics: version)
        }
        return version
    }
}
