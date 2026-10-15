import Foundation
import NetScannerKit

/// The lifecycle of one scan at a time: running, progress, outcome.
///
/// Discovery and port scans share this; each feature model only handles
/// the events that carry results (hosts, ports) and leaves progress,
/// timing, cancellation and errors to this type.
@Observable
final class ScanActivity {
    enum State: Equatable {
        case idle
        /// `progress` is nil until the engine's first progress event.
        case running(progress: ScanProgress?)
        case finished(elapsed: Duration, stopped: Bool)
        case failed(EngineError)
    }

    private(set) var state: State = .idle

    private var task: Task<Void, Never>?
    /// Identifies the current run, so a stopped run that is still winding
    /// down cannot overwrite the state of the one that replaced it.
    private var generation = 0

    var isRunning: Bool {
        if case .running = state { true } else { false }
    }

    /// Runs `stream`, handing every batch to `handle` (after progress has
    /// been applied) until it ends. Any scan already running is stopped.
    func run(
        _ stream: AsyncThrowingStream<[EngineEvent], any Error>,
        handle: @escaping ([EngineEvent]) -> Void
    ) {
        task?.cancel()
        generation += 1
        let run = generation
        state = .running(progress: nil)
        let clock = ContinuousClock()
        let started = clock.now

        task = Task {
            var engineElapsed: Duration?
            do {
                for try await batch in stream {
                    guard run == generation else { return }
                    for event in batch {
                        switch event {
                        case .progress(let progress): apply(progress)
                        case .subnetFinished(_, let elapsed),
                            .portScanFinished(_, let elapsed):
                            engineElapsed = elapsed
                        default: break
                        }
                    }
                    handle(batch)
                }
                guard run == generation else { return }
                let stopped = Task.isCancelled
                state = .finished(elapsed: engineElapsed ?? clock.now - started, stopped: stopped)
            } catch let error as EngineError {
                if run == generation { state = .failed(error) }
            } catch {
                guard run == generation else { return }
                state = .failed(.launchFailed(reason: error.localizedDescription))
            }
        }
    }

    /// Stops the running scan. Results found so far stay.
    func stop() {
        task?.cancel()
        task = nil
    }

    /// Keeps the latest event of each phase. The engine may skip counts,
    /// and a new phase restarts from its own zero, so only a lower count
    /// in the same phase is stale.
    private func apply(_ progress: ScanProgress) {
        guard case .running(let current) = state else { return }
        if let current, current.phase == progress.phase, progress.done < current.done { return }
        state = .running(progress: progress)
    }
}
