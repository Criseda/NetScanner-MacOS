import Foundation
import Synchronization

/// One running `ns` process, feeding an event stream.
///
/// Three things finish independently and in any order: stdout reaches
/// end of file, stderr reaches end of file, and the process exits. The
/// stream finishes once all three have happened, so no output line is
/// lost and the exit status is known when deciding success or failure.
/// The pipe handlers and the termination handler run on Foundation's
/// background queues; all shared state sits behind one mutex.
///
/// Requests for the ARP table (`neighbors_request`) are answered on
/// stdin from the stdout handler, so never on the main actor; the engine
/// waits for the answer, so nothing else is held up meanwhile.
final class EngineRun: Sendable {
    typealias Continuation = AsyncThrowingStream<[EngineEvent], any Error>.Continuation

    private let process: Process
    private let input = Pipe()
    private let readNeighborTable: ScanEngine.NeighborTableReader
    private let continuation: Continuation
    private let state = Mutex(State())
    private let decoder = EngineEventDecoder()

    /// How much of stderr to keep for an error message: its tail is where
    /// the reason is.
    private static let diagnosticsLimit = 4_096

    private struct State: ~Copyable {
        var splitter = LineSplitter()
        var stdoutClosed = false
        var stderrClosed = false
        var exit: (status: Int32, reason: Process.TerminationReason)?
        var rejection: String?
        var diagnostics = Data()
        var cancelled = false
        var finished = false
    }

    init(
        executableURL: URL, arguments: [String],
        readNeighborTable: @escaping ScanEngine.NeighborTableReader, continuation: Continuation
    ) {
        process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        self.readNeighborTable = readNeighborTable
        self.continuation = continuation
    }

    func start() {
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = input
        // Writing to an engine that already exited must fail with EPIPE,
        // not kill the app with SIGPIPE.
        _ = fcntl(input.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)

        stdout.fileHandleForReading.readabilityHandler = { [self] handle in
            readStdout(handle)
        }
        stderr.fileHandleForReading.readabilityHandler = { [self] handle in
            readStderr(handle)
        }
        process.terminationHandler = { [self] process in
            update { $0.exit = (process.terminationStatus, process.terminationReason) }
        }

        do {
            try process.run()
        } catch {
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            try? input.fileHandleForWriting.close()
            state.withLock { $0.finished = true }
            continuation.finish(
                throwing: EngineError.launchFailed(reason: error.localizedDescription))
        }
    }

    /// Stops the engine. Results already streamed stay valid.
    func cancel() {
        state.withLock { $0.cancelled = true }
        if process.isRunning { process.terminate() }
    }

    // MARK: - Output

    private func readStdout(_ handle: FileHandle) {
        let chunk = handle.availableData
        guard !chunk.isEmpty else {
            handle.readabilityHandler = nil
            let lastLine = state.withLock { $0.splitter.finish() }
            if let lastLine { deliver([lastLine]) }
            // Requests come on stdout, so none can follow.
            try? input.fileHandleForWriting.close()
            update { $0.stdoutClosed = true }
            return
        }
        let lines = state.withLock { $0.splitter.append(chunk) }
        deliver(lines)
    }

    private func readStderr(_ handle: FileHandle) {
        let chunk = handle.availableData
        guard !chunk.isEmpty else {
            handle.readabilityHandler = nil
            update { $0.stderrClosed = true }
            return
        }
        state.withLock { state in
            state.diagnostics.append(chunk)
            let excess = state.diagnostics.count - Self.diagnosticsLimit
            if excess > 0 { state.diagnostics.removeFirst(excess) }
        }
    }

    /// Decodes lines and yields the events. Called only from the stdout
    /// handler, which Foundation runs serially, so batches stay in order.
    private func deliver(_ lines: [Data]) {
        var events: [EngineEvent] = []
        events.reserveCapacity(lines.count)
        for line in lines {
            switch decoder.decode(line) {
            case .failure(let message)?:
                state.withLock { $0.rejection = $0.rejection ?? message }
            case .neighborsRequest(let id)?:
                answerNeighborsRequest(id)
            case let event?:
                events.append(event)
            case nil:
                continue
            }
        }
        if !events.isEmpty { continuation.yield(events) }
    }

    /// Sends the ARP table, or why it could not be read. A failed write
    /// means the engine is gone or stopped listening; it then reads the
    /// table itself, so there is nothing to report.
    private func answerNeighborsRequest(_ id: Int) {
        let table = Result { () throws(NeighborTableError) in try readNeighborTable() }
        let reply = NeighborsReply(id: id, table: table)
        try? input.fileHandleForWriting.write(contentsOf: reply.line)
    }

    // MARK: - Completion

    /// Applies a change, then finishes the stream if that was the last of
    /// the three things being waited for.
    private func update(_ change: (inout State) -> Void) {
        let outcome: Result<Void, EngineError>? = state.withLock { state in
            change(&state)
            guard !state.finished, state.stdoutClosed, state.stderrClosed,
                let exit = state.exit
            else { return nil }
            state.finished = true
            return Self.outcome(of: state, exit: exit)
        }
        switch outcome {
        case .success?: continuation.finish()
        case .failure(let error)?: continuation.finish(throwing: error)
        case nil: break
        }
    }

    private static func outcome(
        of state: borrowing State, exit: (status: Int32, reason: Process.TerminationReason)
    ) -> Result<Void, EngineError> {
        if let rejection = state.rejection { return .failure(.rejected(message: rejection)) }
        if state.cancelled { return .success(()) }
        guard exit.reason == .exit, exit.status == 0 else {
            let diagnostics = String(decoding: state.diagnostics, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return .failure(.failed(status: exit.status, diagnostics: diagnostics))
        }
        return .success(())
    }
}
