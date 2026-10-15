import Foundation

/// The app's answer to the engine's `neighbors_request`: one line on the
/// engine's stdin carrying the ARP table, or why it could not be read
/// (the engine then reads the table itself).
///
/// macOS keeps no reachability state in the table, so every entry is
/// sent as `stale`, which is what the engine expects there.
struct NeighborsReply: Encodable, Sendable {
    private let type = "neighbors"
    let id: Int
    let entries: [Entry]?
    let error: String?

    struct Entry: Encodable, Sendable {
        let ip: String
        let mac: String
        let state = "stale"
    }

    init(id: Int, table: Result<[NeighborEntry], NeighborTableError>) {
        self.id = id
        switch table {
        case .success(let table):
            entries = table.map { Entry(ip: $0.ip.description, mac: $0.macAddress) }
            error = nil
        case .failure(let failure):
            entries = nil
            error = failure.message
        }
    }

    /// The reply as one newline-terminated JSON line.
    var line: Data {
        let encoder = JSONEncoder()
        // Sorted keys make the line predictable; the engine does not care.
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        // Encoding plain strings and numbers cannot fail; an empty line
        // would only make the engine read the table itself.
        var line = (try? encoder.encode(self)) ?? Data()
        line.append(UInt8(ascii: "\n"))
        return line
    }
}
