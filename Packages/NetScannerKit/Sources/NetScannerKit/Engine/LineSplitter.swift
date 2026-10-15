import Foundation

/// Splits a byte stream into newline-terminated lines.
///
/// Pipe reads return whatever bytes are available, which can end in the
/// middle of a line; the partial line is kept until the rest arrives.
struct LineSplitter: Sendable {
    private var pending = Data()

    /// Returns every line completed by `chunk`, without the newline (and
    /// without a `\r` before it).
    mutating func append(_ chunk: Data) -> [Data] {
        pending.append(chunk)
        var lines: [Data] = []
        var lineStart = pending.startIndex
        while let newline = pending[lineStart...].firstIndex(of: UInt8(ascii: "\n")) {
            lines.append(Self.trimmingCarriageReturn(pending[lineStart..<newline]))
            lineStart = pending.index(after: newline)
        }
        pending.removeSubrange(pending.startIndex..<lineStart)
        return lines
    }

    /// The last line, when the stream ended without a newline.
    mutating func finish() -> Data? {
        defer { pending = Data() }
        return pending.isEmpty ? nil : Self.trimmingCarriageReturn(pending)
    }

    private static func trimmingCarriageReturn(_ line: Data) -> Data {
        line.last == UInt8(ascii: "\r") ? Data(line.dropLast()) : Data(line)
    }
}
