import SwiftUI

/// The Scan menu, so every scan action has a menu item and a shortcut.
struct ScanCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandMenu("Scan") {
            Button("Start Scan", systemImage: "play.fill") { model.startScan() }
                .keyboardShortcut("r")
                .disabled(!model.canStartScan)

            Button("Stop Scan", systemImage: "stop.fill") { model.stopScan() }
                .keyboardShortcut(".")
                .disabled(!model.activeActivity.isRunning)

            Divider()

            ForEach(Array(AppModel.Section.allCases.enumerated()), id: \.element) { index, section in
                Button(String(localized: section.title), systemImage: section.symbolName) {
                    model.section = section
                }
                .keyboardShortcut(KeyEquivalent(Character(String(index + 1))))
            }
        }
    }
}
