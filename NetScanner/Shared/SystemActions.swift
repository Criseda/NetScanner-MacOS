import AppKit
import UniformTypeIdentifiers

/// Small bridges to AppKit for things SwiftUI has no API for.
enum SystemActions {
    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Privacy & Security ▸ Local Network, where the user can allow
    /// NetScanner after declining the first prompt.
    static func openLocalNetworkSettings() {
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork")
        {
            NSWorkspace.shared.open(url)
        }
    }

    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
