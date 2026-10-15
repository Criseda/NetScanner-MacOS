import SwiftUI

/// The window's primary action: Scan, or Stop while a scan runs.
struct ScanToolbarButton: View {
    let isRunning: Bool
    let canStart: Bool
    let start: () -> Void
    let stop: () -> Void

    var body: some View {
        if isRunning {
            Button("Stop", systemImage: "stop.fill", action: stop)
                .help("Stop the scan (⌘.)")
        } else {
            Button("Scan", systemImage: "play.fill", action: start)
                .buttonStyle(.glassProminent)
                .disabled(!canStart)
                .help("Start the scan (⌘R)")
        }
    }
}
