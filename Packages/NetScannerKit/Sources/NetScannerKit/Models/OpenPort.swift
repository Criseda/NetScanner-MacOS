import Foundation

/// One open TCP port, named from the engine's embedded port table.
public struct OpenPort: Identifiable, Hashable, Sendable {
    public let port: UInt16
    /// Display name, e.g. "SSH" or "Home Assistant".
    public let service: String?
    /// The service IANA officially registers for the port; nil when the
    /// name comes only from common use.
    public let iana: String?
    public let description: String?
    public let category: PortCategory?

    public var id: UInt16 { port }

    public init(
        port: UInt16, service: String? = nil, iana: String? = nil,
        description: String? = nil, category: PortCategory? = nil
    ) {
        self.port = port
        self.service = service
        self.iana = iana
        self.description = description
        self.category = category
    }

    /// The description, unless it only repeats a name already shown
    /// (IANA registers many ports with their own name as description).
    public var distinctDescription: String? {
        guard let description else { return nil }
        let repeatsName = [service, iana].contains {
            $0?.caseInsensitiveCompare(description) == .orderedSame
        }
        return repeatsName ? nil : description
    }

    /// Whether "Open in Browser" makes sense.
    public var isWeb: Bool { category == .web }

    /// HTTPS when the names say so, HTTP otherwise.
    public var webScheme: String {
        let names = [service, iana].compactMap { $0?.lowercased() }
        let secure = port == 443 || port == 8443 || names.contains { $0.contains("https") }
        return secure ? "https" : "http"
    }

    public func webURL(host: IPv4) -> URL? {
        URL(string: "\(webScheme)://\(host):\(port)")
    }

    /// "22 SSH", for one-line summaries.
    public var shortText: String {
        service.map { "\(port) \($0)" } ?? "\(port)"
    }

    /// Everything searchable about the port, for the search field.
    public func matches(_ query: String) -> Bool {
        String(port).contains(query)
            || [service, iana, description, category?.label].contains {
                $0?.localizedStandardContains(query) ?? false
            }
    }
}

extension Collection<OpenPort> {
    /// "22 SSH, 80 HTTP, +2 more" for a table cell.
    public func summary(limit: Int = 3) -> String {
        guard !isEmpty else { return String(localized: "None open", bundle: .module) }
        let sorted = self.sorted { $0.port < $1.port }
        let shown = sorted.prefix(limit).map(\.shortText).joined(separator: ", ")
        let hidden = count - limit
        return hidden > 0
            ? String(localized: "\(shown), +\(hidden) more", bundle: .module) : shown
    }
}
