import Foundation
import Testing

@testable import NetScannerKit

/// Runs ``ScanEngine`` against small shell scripts standing in for `ns`,
/// so process handling (streaming, exit codes, cancellation) is tested
/// without touching the network.
@Suite("Scan engine process handling")
struct ScanEngineTests {
    @Test func streamsEventsAndFinishes() async throws {
        let engine = try fakeEngine(
            """
            echo '{"type":"start","mode":"subnet","cidr":"10.0.0.0/30","first":"10.0.0.0","last":"10.0.0.3"}'
            echo 'diagnostic on stderr' >&2
            echo '{"type":"host","ip":"10.0.0.1","source":"tcp"}'
            printf '{"type":"summary","hosts":1,"elapsed_ms":7}'
            """)
        let events = try await collect(engine)
        #expect(
            events == [
                .subnetStarted(first: IPv4(10, 0, 0, 0), last: IPv4(10, 0, 0, 3)),
                .hostFound(IPv4(10, 0, 0, 1), .tcp),
                .subnetFinished(hostCount: 1, elapsed: .milliseconds(7)),
            ])
    }

    @Test func throwsTheEngineRejection() async throws {
        let engine = try fakeEngine(
            """
            echo '{"type":"error","message":"Invalid subnet"}'
            exit 1
            """)
        await #expect(throws: EngineError.rejected(message: "Invalid subnet")) {
            _ = try await collect(engine)
        }
    }

    @Test func reportsCrashesWithDiagnostics() async throws {
        let engine = try fakeEngine(
            """
            echo 'out of memory' >&2
            exit 3
            """)
        await #expect(throws: EngineError.failed(status: 3, diagnostics: "out of memory")) {
            _ = try await collect(engine)
        }
    }

    @Test func reportsAMissingEngine() async {
        let engine = ScanEngine(executableURL: URL(filePath: "/nonexistent/ns"))
        await #expect(throws: EngineError.missing(path: "/nonexistent/ns")) {
            _ = try await collect(engine)
        }
    }

    @Test func cancellingStopsTheEngine() async throws {
        let engine = try fakeEngine(
            """
            echo '{"type":"host","ip":"10.0.0.1","source":"tcp"}'
            exec sleep 30
            """)
        let clock = ContinuousClock()
        let started = clock.now
        let task = Task {
            for try await batch in engine.scan(request) where batch.contains(.hostFound(IPv4(10, 0, 0, 1), .tcp)) {
                return true
            }
            return false
        }
        #expect(try await task.value)
        // Leaving the loop drops the stream, which must terminate `sleep`
        // rather than wait out its 30 seconds.
        #expect(clock.now - started < .seconds(10))
    }

    @Test func answersNeighborsRequestsOnStdin() async throws {
        // The fake engine sends the reply back on stderr, and fails so
        // that it shows up in the error.
        let table = [NeighborEntry(ip: IPv4(10, 0, 0, 2), macAddress: "aa:bb:cc:dd:ee:ff")]
        let engine = try fakeEngine(
            """
            echo '{"type":"neighbors_request","id":1}'
            read -r reply
            echo "$reply" >&2
            exit 3
            """, neighborTable: table)
        let reply = #"{"entries":[{"ip":"10.0.0.2","mac":"aa:bb:cc:dd:ee:ff","state":"stale"}],"id":1,"type":"neighbors"}"#
        await #expect(throws: EngineError.failed(status: 3, diagnostics: reply)) {
            _ = try await collect(engine)
        }
    }

    @Test func keepsNeighborsRequestsOutOfTheStream() async throws {
        let engine = try fakeEngine(
            """
            echo '{"type":"neighbors_request","id":1}'
            read -r reply
            echo '{"type":"host","ip":"10.0.0.2","source":"arp"}'
            """, neighborTable: [])
        #expect(try await collect(engine) == [.hostFound(IPv4(10, 0, 0, 2), .arp)])
    }

    @Test func readsTheVersion() async throws {
        let engine = try fakeEngine("echo v9.9.9")
        #expect(try await engine.version() == "v9.9.9")
    }

    // MARK: - Helpers

    private let request = ScanRequest.discovery(
        DiscoveryOptions(subnet: Subnet(address: IPv4(10, 0, 0, 0), prefixLength: 30)))

    private func collect(_ engine: ScanEngine) async throws -> [EngineEvent] {
        var events: [EngineEvent] = []
        for try await batch in engine.scan(request) { events += batch }
        return events
    }

    private func fakeEngine(_ script: String, neighborTable: [NeighborEntry] = []) throws -> ScanEngine {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "fake-ns-\(UUID().uuidString)")
        try "#!/bin/sh\n\(script)\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return ScanEngine(executableURL: url, readNeighborTable: { neighborTable })
    }
}
