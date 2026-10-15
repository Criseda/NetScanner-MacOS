import Foundation

/// Plain-text forms of scan results, for the clipboard and for files.
public enum ResultExport {
    // MARK: Hosts

    private static var hostHeaders: [String] {
        [
            String(localized: "Name", bundle: .module),
            String(localized: "IP Address", bundle: .module),
            String(localized: "Manufacturer", bundle: .module),
            String(localized: "MAC Address", bundle: .module),
            String(localized: "Found Via", bundle: .module),
            String(localized: "Open Ports", bundle: .module),
        ]
    }

    private static func row(_ host: DiscoveredHost) -> [String] {
        [
            host.hostname ?? "", host.ip.description, host.vendor ?? "", host.macAddress ?? "",
            host.source.label, host.openPorts.map { $0.map(\.shortText).joined(separator: ", ") } ?? "",
        ]
    }

    public static func csv(_ hosts: some Sequence<DiscoveredHost>) -> String {
        csv(headers: hostHeaders, rows: hosts.map(row))
    }

    /// Tab-separated, so it pastes into Numbers or a spreadsheet as cells
    /// and still reads fine in a note.
    public static func tabSeparated(_ hosts: some Sequence<DiscoveredHost>) -> String {
        tabSeparated(headers: hostHeaders, rows: hosts.map(row))
    }

    // MARK: Ports

    private static var portHeaders: [String] {
        [
            String(localized: "Port", bundle: .module),
            String(localized: "Service", bundle: .module),
            String(localized: "Category", bundle: .module),
            String(localized: "IANA Name", bundle: .module),
            String(localized: "Description", bundle: .module),
        ]
    }

    private static func row(_ port: OpenPort) -> [String] {
        [
            String(port.port), port.service ?? "", port.category?.label ?? "", port.iana ?? "",
            port.distinctDescription ?? "",
        ]
    }

    public static func csv(_ ports: some Sequence<OpenPort>) -> String {
        csv(headers: portHeaders, rows: ports.map(row))
    }

    public static func tabSeparated(_ ports: some Sequence<OpenPort>) -> String {
        tabSeparated(headers: portHeaders, rows: ports.map(row))
    }

    // MARK: Formats

    /// RFC 4180: fields with commas, quotes or line breaks are quoted,
    /// quotes doubled, lines end in CRLF.
    static func csv(headers: [String], rows: [[String]]) -> String {
        ([headers] + rows)
            .map { $0.map(csvField).joined(separator: ",") }
            .joined(separator: "\r\n") + "\r\n"
    }

    private static func csvField(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func tabSeparated(headers: [String], rows: [[String]]) -> String {
        ([headers] + rows)
            .map { $0.map(tsvField).joined(separator: "\t") }
            .joined(separator: "\n") + "\n"
    }

    private static func tsvField(_ field: String) -> String {
        String(field.map { $0 == "\t" || $0.isNewline ? " " : $0 })
    }
}
