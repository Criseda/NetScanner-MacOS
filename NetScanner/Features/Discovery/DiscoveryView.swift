import NetScannerKit
import SwiftUI

/// Find live hosts on a subnet (`ns -s`).
struct DiscoveryView: View {
    @Environment(AppModel.self) private var app
    @State private var showsInspector = false
    @State private var exportedCSV: CSVDocument?
    @SceneStorage("discovery.columns") private var columns = TableColumnCustomization<DiscoveredHost>()

    private var model: DiscoveryModel { app.discovery }

    var body: some View {
        @Bindable var model = model

        HostTable(
            model: model, columns: $columns,
            scanPorts: app.scanPorts(of:),
            showDetails: { showsInspector = true }
        )
        .overlay { emptyState }
        .overlay(alignment: .bottom) {
            // Animated on its own, so results and empty states swap instantly.
            ZStack {
                if case .running(let progress) = model.activity.state {
                    ScanStatusCapsule(
                        progress: progress, target: model.scannedSubnet?.description ?? "")
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.smooth, value: model.activity.isRunning)
        }
        .navigationTitle("Discovery")
        .navigationSubtitle(subtitle)
        .searchable(text: $model.searchText, prompt: "Search hosts")
        .toolbar { toolbar }
        .inspector(isPresented: $showsInspector) {
            HostInspector(hosts: model.selectedHosts, scanPorts: app.scanPorts(of:))
                .inspectorColumnWidth(min: 260, ideal: 300, max: 420)
        }
        .confirmationDialog(
            largeScanTitle, isPresented: $model.needsLargeScanConfirmation, titleVisibility: .visible
        ) {
            Button("Scan") { app.startDiscovery(confirmed: true) }
        } message: {
            Text("Large sweeps take longer and send many probes. Make sure you are allowed to scan this network.")
        }
        .fileExporter(
            isPresented: Binding(get: { exportedCSV != nil }, set: { if !$0 { exportedCSV = nil } }),
            document: exportedCSV, contentType: .commaSeparatedText,
            defaultFilename: "Hosts \(model.scannedSubnet?.description ?? "")"
        ) { _ in }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        @Bindable var model = model

        ToolbarItem(placement: .principal) {
            SubnetField(
                text: $model.subnetText, error: model.validatedSubnet.error,
                networks: app.localNetworks, refreshNetworks: app.refreshLocalNetworks,
                submit: app.startScan)
        }

        ToolbarItem(placement: .principal) {
            Menu("Options", systemImage: "slider.horizontal.3") {
                Picker("Method", selection: $model.method) {
                    Text("TCP, Multicast and ARP").tag(DiscoveryOptions.Method.standard)
                    Text("ICMP Ping").tag(DiscoveryOptions.Method.ping)
                }
                .pickerStyle(.inline)
                Toggle("Identify Devices", isOn: $model.identifyDevices)
            }
            .help("Discovery method and device identification")
        }

        ToolbarItem(placement: .primaryAction) {
            ScanToolbarButton(
                isRunning: model.activity.isRunning, canStart: app.canStartScan,
                start: app.startScan, stop: app.stopScan)
        }

        ToolbarItem {
            Menu("Export", systemImage: "square.and.arrow.up") {
                Button("Copy All Hosts") {
                    SystemActions.copy(ResultExport.tabSeparated(model.visibleHosts))
                }
                Button("Export as CSV…") {
                    exportedCSV = CSVDocument(text: ResultExport.csv(model.visibleHosts))
                }
            }
            .disabled(model.visibleHosts.isEmpty)
        }

        ToolbarItem {
            Button("Inspector", systemImage: "sidebar.trailing") { showsInspector.toggle() }
                .help("Show or hide host details")
        }
    }

    // MARK: Status

    private var subtitle: String {
        switch model.activity.state {
        case .idle, .failed:
            return ""
        case .running:
            return .inflected("^[\(model.hostCount) host](inflect: true) found")
        case .finished(let elapsed, let stopped):
            let summary = String.inflected("^[\(model.hostCount) host](inflect: true) in \(elapsed.formattedSeconds)")
            return stopped ? String(localized: "\(summary), stopped") : summary
        }
    }

    private var largeScanTitle: String {
        let count = (try? model.validatedSubnet.get())?.usableHostCount ?? 0
        return String(localized: "Scan \(count.formatted()) hosts?")
    }

    @ViewBuilder
    private var emptyState: some View {
        if case .unavailable(let error) = app.engineStatus {
            EngineUnavailableView(error: error)
        } else if model.visibleHosts.isEmpty, !model.activity.isRunning {
            if model.hostCount > 0 {
                ContentUnavailableView.search(text: model.searchText)
            } else {
                DiscoveryEmptyState(
                    state: model.activity.state,
                    subnet: try? model.validatedSubnet.get(),
                    scan: app.startScan)
            }
        }
    }
}

extension Result {
    var error: Failure? {
        if case .failure(let error) = self { error } else { nil }
    }
}

extension Duration {
    /// "1.4 s"
    var formattedSeconds: String {
        formatted(.units(allowed: [.seconds], width: .abbreviated, fractionalPart: .show(length: 1)))
    }
}
