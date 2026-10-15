import Foundation

/// The engine's coarse grouping of a port's service (`port.category`).
///
/// The engine keeps the ids stable and lowercase and leaves wording to
/// frontends. An id this build does not know yet is shown capitalized
/// rather than hidden.
public enum PortCategory: Hashable, Sendable {
    case web, remote, file, mail, dns, database, directory, media
    case printing, messaging, voip, network, vpn, proxy, home
    case other(String)

    public init?(engineValue: String?) {
        guard let engineValue, !engineValue.isEmpty else { return nil }
        self =
            switch engineValue {
            case "web": .web
            case "remote": .remote
            case "file": .file
            case "mail": .mail
            case "dns": .dns
            case "database": .database
            case "directory": .directory
            case "media": .media
            case "printing": .printing
            case "messaging": .messaging
            case "voip": .voip
            case "network": .network
            case "vpn": .vpn
            case "proxy": .proxy
            case "home": .home
            default: .other(engineValue)
            }
    }

    public var label: String {
        switch self {
        case .web: String(localized: "Web", bundle: .module)
        case .remote: String(localized: "Remote access", bundle: .module)
        case .file: String(localized: "File sharing", bundle: .module)
        case .mail: String(localized: "Mail", bundle: .module)
        case .dns: String(localized: "DNS", bundle: .module)
        case .database: String(localized: "Database", bundle: .module)
        case .directory: String(localized: "Directory", bundle: .module)
        case .media: String(localized: "Media", bundle: .module)
        case .printing: String(localized: "Printing", bundle: .module)
        case .messaging: String(localized: "Messaging", bundle: .module)
        case .voip: String(localized: "Voice & video", bundle: .module)
        case .network: String(localized: "Network", bundle: .module)
        case .vpn: String(localized: "VPN", bundle: .module)
        case .proxy: String(localized: "Proxy", bundle: .module)
        case .home: String(localized: "Smart home", bundle: .module)
        case .other(let id): id.prefix(1).uppercased() + id.dropFirst()
        }
    }

    /// An SF Symbol name for the category, so a long port list can be
    /// scanned by eye.
    public var symbolName: String {
        switch self {
        case .web: "globe"
        case .remote: "terminal"
        case .file: "folder"
        case .mail: "envelope"
        case .dns: "signpost.right"
        case .database: "cylinder.split.1x2"
        case .directory: "person.2"
        case .media: "play.rectangle"
        case .printing: "printer"
        case .messaging: "bubble.left.and.bubble.right"
        case .voip: "phone"
        case .network: "network"
        case .vpn: "lock.shield"
        case .proxy: "arrow.triangle.branch"
        case .home: "house"
        case .other: "questionmark.circle"
        }
    }
}
