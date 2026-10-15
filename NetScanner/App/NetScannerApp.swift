import SwiftUI

@main
struct NetScannerApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        // One window: the app is a single tool, and a second window
        // would only race the first for the same network.
        Window("NetScanner", id: "main") {
            ContentView()
                .environment(model)
                .task { await model.checkEngine() }
        }
        .defaultSize(width: 1_100, height: 680)
        .commands { ScanCommands(model: model) }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
