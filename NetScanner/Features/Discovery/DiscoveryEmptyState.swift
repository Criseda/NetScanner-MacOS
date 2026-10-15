import NetScannerKit
import SwiftUI

/// What the Discovery screen shows instead of an empty table.
struct DiscoveryEmptyState: View {
    let state: ScanActivity.State
    let subnet: Subnet?
    let scan: () -> Void

    var body: some View {
        switch state {
        case .idle, .running:
            ContentUnavailableView {
                Label("Discover Devices", systemImage: "network")
            } description: {
                Text("Find every device on your network: computers, phones, printers, TVs and smart home gear.")
            } actions: {
                if let subnet {
                    Button("Scan \(subnet.description)", action: scan)
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                }
            }

        case .finished(_, let stopped):
            ContentUnavailableView {
                Label(stopped ? "Scan Stopped" : "No Devices Found", systemImage: "wifi.exclamationmark")
            } description: {
                Text("If macOS asked whether NetScanner may find devices on your local network, it needs that permission. You can turn it on in Privacy & Security.")
            } actions: {
                Button("Open Privacy Settings", action: SystemActions.openLocalNetworkSettings)
                Button("Scan Again", action: scan)
            }

        case .failed(let error):
            ContentUnavailableView {
                Label("Scan Failed", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.localizedDescription)
                if let reason = error.failureReason {
                    Text(reason)
                }
            } actions: {
                Button("Try Again", action: scan)
            }
        }
    }
}

/// Shown on every screen when the bundled engine cannot run.
struct EngineUnavailableView: View {
    let error: EngineError

    var body: some View {
        ContentUnavailableView {
            Label("Scan Engine Unavailable", systemImage: "exclamationmark.octagon")
        } description: {
            Text(error.localizedDescription)
            if let reason = error.failureReason {
                Text(reason)
            }
        }
    }
}
