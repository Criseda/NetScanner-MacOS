import NetScannerKit
import SwiftUI

/// Find open TCP ports on one host (`ns -p`).
struct PortScanView: View {
    @Environment(AppModel.self) private var app
    @State private var exportedCSV: CSVDocument?
    @SceneStorage("portScan.columns") private var columns = TableColumnCustomization<OpenPort>()

    private var model: PortScanModel { app.portScan }

    var body: some View {
        @Bindable var model = model

        PortTable(model: model, columns: $columns)
            .overlay { emptyState }
            .overlay(alignment: .bottom) {
                // Animated on its own, so results and empty states swap instantly.
                ZStack {
                    if case .running(let progress) = model.activity.state {
                        ScanStatusCapsule(
                            progress: progress, target: model.scannedHost?.description ?? "")
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.smooth, value: model.activity.isRunning)
            }
            .navigationTitle("Port Scan")
            .navigationSubtitle(subtitle)
            .searchable(text: $model.searchText, prompt: "Search ports")
            .toolbar { toolbar }
            .fileExporter(
                isPresented: Binding(get: { exportedCSV != nil }, set: { if !$0 { exportedCSV = nil } }),
                document: exportedCSV, contentType: .commaSeparatedText,
                defaultFilename: "Open ports \(model.scannedHost?.description ?? "")"
            ) { _ in }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        @Bindable var model = model

        ToolbarItem(placement: .principal) {
            PortScanForm(
                hostText: $model.hostText, rangeText: $model.rangeText,
                error: model.validatedOptions.error,
                knownHosts: app.discovery.visibleHosts.sorted(using: HostComparator(.ip)),
                submit: app.startScan)
        }

        ToolbarItem(placement: .primaryAction) {
            ScanToolbarButton(
                isRunning: model.activity.isRunning, canStart: app.canStartScan,
                start: app.startScan, stop: app.stopScan)
        }

        ToolbarItem {
            Menu("Export", systemImage: "square.and.arrow.up") {
                Button("Copy All Ports") {
                    SystemActions.copy(ResultExport.tabSeparated(model.visiblePorts))
                }
                Button("Export as CSV…") {
                    exportedCSV = CSVDocument(text: ResultExport.csv(model.visiblePorts))
                }
            }
            .disabled(model.visiblePorts.isEmpty)
        }
    }

    // MARK: Status

    private var subtitle: String {
        switch model.activity.state {
        case .idle, .failed:
            return ""
        case .running:
            return .inflected("^[\(model.portCount) open port](inflect: true) found")
        case .finished(let elapsed, let stopped):
            let summary = String.inflected("^[\(model.portCount) open port](inflect: true) in \(elapsed.formattedSeconds)")
            return stopped ? String(localized: "\(summary), stopped") : summary
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if case .unavailable(let error) = app.engineStatus {
            EngineUnavailableView(error: error)
        } else if model.visiblePorts.isEmpty, !model.activity.isRunning {
            if model.portCount > 0 {
                ContentUnavailableView.search(text: model.searchText)
            } else {
                PortScanEmptyState(
                    state: model.activity.state, host: model.scannedHost,
                    canScan: app.canStartScan, scan: app.startScan)
            }
        }
    }
}

/// Host and port range, in the toolbar.
private struct PortScanForm: View {
    @Binding var hostText: String
    @Binding var rangeText: String
    let error: InputError?
    let knownHosts: [DiscoveredHost]
    let submit: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Menu {
                Section("Discovered Hosts") {
                    ForEach(knownHosts) { host in
                        Button(host.hostname.map { "\(host.ip) — \($0)" } ?? host.ip.description) {
                            hostText = host.ip.description
                        }
                    }
                }
                if knownHosts.isEmpty {
                    Text("Run a discovery scan to list hosts here")
                }
            } label: {
                Label("Hosts", systemImage: "desktopcomputer")
            }
            .menuIndicator(.hidden)
            .labelStyle(.iconOnly)
            .fixedSize()
            .help("Choose a discovered host")

            TextField("Host", text: $hostText, prompt: Text(verbatim: "192.168.1.1"))
                .accessibilityLabel("Host")
                .textFieldStyle(.plain)
                .monospacedDigit()
                .frame(width: 110)
                .onSubmit(submit)

            Divider().frame(height: 16)

            TextField("Ports", text: $rangeText, prompt: Text(verbatim: "1-1024"))
                .accessibilityLabel("Ports")
                .textFieldStyle(.plain)
                .monospacedDigit()
                .frame(width: 80)
                .onSubmit(submit)
                .accessibilityHint("A port or a range, for example 1-1024")

            Menu {
                Button("Well-Known Ports (1-1024)") { rangeText = PortRange.wellKnown.description }
                Button("All Ports (1-65535)") { rangeText = PortRange.all.description }
            } label: {
                Label("Port Presets", systemImage: "chevron.down")
            }
            .menuIndicator(.hidden)
            .labelStyle(.iconOnly)
            .fixedSize()
            .help("Common port ranges")

            if let error, !hostText.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.multicolor)
                    .help(error.localizedDescription)
                    .accessibilityLabel(error.localizedDescription)
            }
        }
        .padding(.horizontal, 8)
    }
}

/// What the Port Scan screen shows instead of an empty table.
private struct PortScanEmptyState: View {
    let state: ScanActivity.State
    let host: IPv4?
    let canScan: Bool
    let scan: () -> Void

    var body: some View {
        switch state {
        case .idle, .running:
            ContentUnavailableView {
                Label("Scan for Open Ports", systemImage: "door.left.hand.open")
            } description: {
                Text("See which services a device offers. Enter its address, or pick one from Discovery.")
            } actions: {
                Button("Scan", action: scan)
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(!canScan)
            }

        case .finished(_, let stopped):
            ContentUnavailableView {
                Label(stopped ? "Scan Stopped" : "No Open Ports", systemImage: "door.left.hand.closed")
            } description: {
                if let host, !stopped {
                    Text("\(host.description) accepted no connections on these ports.")
                }
            } actions: {
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
