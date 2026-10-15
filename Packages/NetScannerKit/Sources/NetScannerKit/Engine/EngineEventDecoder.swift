import Foundation

/// Turns one line of `ns --json` output into an ``EngineEvent``.
///
/// Lines that are not events (blank, not JSON, an unknown `type`, or a
/// known type missing what it needs) decode to nil and are ignored:
/// the engine adds event types and fields over time, and an older app
/// must keep working with a newer engine.
public struct EngineEventDecoder: Sendable {
    public init() {}

    public func decode(_ line: some DataProtocol) -> EngineEvent? {
        // Every event is an object; skip anything else without paying for
        // a JSON parse (stray diagnostics, blank lines).
        guard line.first(where: { $0 != UInt8(ascii: " ") }) == UInt8(ascii: "{"),
            let raw = try? JSONDecoder().decode(RawEvent.self, from: Data(line))
        else { return nil }
        return raw.event
    }
}

/// The union of every event's fields. Decoding them all as optionals
/// keeps one forgiving decode path instead of one type per event.
private struct RawEvent: Decodable {
    let type: String
    let ip: String?
    let source: String?
    let hostname: String?
    let mac: String?
    let vendor: String?
    let first: String?
    let last: String?
    let port: Int?
    let service: String?
    let iana: String?
    let description: String?
    let category: String?
    let phase: String?
    let done: Int?
    let total: Int?
    let hosts: Int?
    let openPorts: [Int]?
    let elapsedMs: Int?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case type, ip, source, hostname, mac, vendor, first, last, port, service, iana
        case description, category, phase, done, total, hosts, message
        case openPorts = "open_ports"
        case elapsedMs = "elapsed_ms"
    }

    var event: EngineEvent? {
        switch type {
        case "start":
            guard let first = first.flatMap(IPv4.init), let last = last.flatMap(IPv4.init) else {
                return nil
            }
            return .subnetStarted(first: first, last: last)

        case "host":
            guard let ip = ip.flatMap(IPv4.init) else { return nil }
            return .hostFound(ip, HostSource(engineValue: source))

        case "host_detail":
            guard let ip = ip.flatMap(IPv4.init) else { return nil }
            return .hostDetail(
                HostDetail(ip: ip, hostname: hostname, macAddress: mac, vendor: vendor))

        case "port":
            guard let port = port.flatMap(Self.validPort) else { return nil }
            return .portFound(
                OpenPort(
                    port: port, service: service, iana: iana, description: description,
                    category: PortCategory(engineValue: category)))

        case "progress":
            guard let phase, !phase.isEmpty, let done, let total, total > 0 else { return nil }
            return .progress(
                ScanProgress(phase: ScanPhase(engineValue: phase), done: done, total: total))

        case "summary":
            let elapsed = Duration.milliseconds(elapsedMs ?? 0)
            if let openPorts {
                return .portScanFinished(
                    openPorts: openPorts.compactMap(Self.validPort), elapsed: elapsed)
            }
            guard let hosts else { return nil }
            return .subnetFinished(hostCount: hosts, elapsed: elapsed)

        case "error":
            return .failure(message: message ?? String(localized: "The scan engine reported an error.", bundle: .module))

        default:
            return nil
        }
    }

    private static func validPort(_ value: Int) -> UInt16? {
        (1...65_535).contains(value) ? UInt16(value) : nil
    }
}
