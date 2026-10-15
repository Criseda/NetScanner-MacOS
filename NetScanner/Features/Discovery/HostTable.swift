import NetScannerKit
import SwiftUI

/// The discovered hosts: sortable, searchable, multi-select, with
/// customizable columns.
struct HostTable: View {
    @Bindable var model: DiscoveryModel
    @Binding var columns: TableColumnCustomization<DiscoveredHost>
    let scanPorts: (IPv4) -> Void
    let showDetails: () -> Void

    var body: some View {
        Table(
            model.visibleHosts, selection: $model.selection, sortOrder: $model.sortOrder,
            columnCustomization: $columns
        ) {
            TableColumn("Name", sortUsing: HostComparator(.name)) { host in
                OptionalText(host.hostname)
            }
            .width(min: 120, ideal: 180)
            .customizationID("name")

            TableColumn("IP Address", sortUsing: HostComparator(.ip)) { host in
                Text(host.ip.description).monospacedDigit()
            }
            .width(min: 100, ideal: 120)
            .customizationID("ip")

            TableColumn("Manufacturer", sortUsing: HostComparator(.vendor)) { host in
                OptionalText(host.vendor)
            }
            .width(min: 120, ideal: 200)
            .customizationID("vendor")

            TableColumn("MAC Address", sortUsing: HostComparator(.macAddress)) { host in
                OptionalText(host.macAddress).monospaced()
            }
            .width(min: 120, ideal: 140)
            .customizationID("mac")

            TableColumn("Found Via", sortUsing: HostComparator(.source)) { host in
                Text(host.source.label).foregroundStyle(.secondary)
            }
            .width(min: 60, ideal: 70)
            .customizationID("source")

            TableColumn("Open Ports", sortUsing: HostComparator(.openPorts)) { host in
                OptionalText(host.openPorts?.summary())
                    .help(host.openPorts.map { $0.map(\.shortText).joined(separator: ", ") } ?? "")
            }
            .width(min: 100, ideal: 180)
            .customizationID("ports")
        }
        // Stripes behind an empty-state message read as clutter.
        .alternatingRowBackgrounds(model.visibleHosts.isEmpty ? .disabled : .enabled)
        .contextMenu(forSelectionType: IPv4.self) { selection in
            menu(for: selection)
        } primaryAction: { _ in
            showDetails()
        }
        .onCopyCommand {
            [NSItemProvider(object: ResultExport.tabSeparated(model.selectedHosts) as NSString)]
        }
    }

    @ViewBuilder
    private func menu(for selection: Set<IPv4>) -> some View {
        let hosts = model.visibleHosts.filter { selection.contains($0.ip) }
        if let host = hosts.first, hosts.count == 1 {
            Button("Scan Ports", systemImage: "door.left.hand.open") { scanPorts(host.ip) }
            Button("Show Details", systemImage: "info.circle", action: showDetails)

            let webPorts = host.openPorts?.filter(\.isWeb) ?? []
            if !webPorts.isEmpty {
                Menu("Open in Browser", systemImage: "safari") {
                    ForEach(webPorts) { port in
                        if let url = port.webURL(host: host.ip) {
                            Button(url.absoluteString) { SystemActions.open(url) }
                        }
                    }
                }
            }
            Divider()
            Button("Copy IP Address") { SystemActions.copy(host.ip.description) }
            if let hostname = host.hostname {
                Button("Copy Name") { SystemActions.copy(hostname) }
            }
            if let mac = host.macAddress {
                Button("Copy MAC Address") { SystemActions.copy(mac) }
            }
        }
        if !hosts.isEmpty {
            Button(hosts.count == 1 ? "Copy Row" : "Copy \(hosts.count) Rows") {
                SystemActions.copy(ResultExport.tabSeparated(hosts))
            }
        }
    }
}

/// A table cell that shows a dash for a missing value.
struct OptionalText: View {
    let value: String?

    init(_ value: String?) {
        self.value = value
    }

    var body: some View {
        if let value {
            Text(value)
        } else {
            Text(verbatim: "—")
                .foregroundStyle(.tertiary)
                .accessibilityLabel("None")
        }
    }

    func monospaced() -> some View {
        fontDesign(.monospaced)
    }
}
