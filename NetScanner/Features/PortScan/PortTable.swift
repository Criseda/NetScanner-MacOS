import NetScannerKit
import SwiftUI

/// The open ports of the scanned host.
struct PortTable: View {
    @Bindable var model: PortScanModel
    @Binding var columns: TableColumnCustomization<OpenPort>

    var body: some View {
        Table(
            model.visiblePorts, selection: $model.selection, sortOrder: $model.sortOrder,
            columnCustomization: $columns
        ) {
            TableColumn("Port", sortUsing: OpenPortComparator(.port)) { port in
                Text(verbatim: "\(port.port)").monospacedDigit().fontWeight(.medium)
            }
            .width(min: 50, ideal: 60)
            .customizationID("port")

            TableColumn("Service", sortUsing: OpenPortComparator(.service)) { port in
                OptionalText(port.service)
            }
            .width(min: 100, ideal: 150)
            .customizationID("service")

            TableColumn("Category", sortUsing: OpenPortComparator(.category)) { port in
                if let category = port.category {
                    Label(category.label, systemImage: category.symbolName)
                } else {
                    OptionalText(nil)
                }
            }
            .width(min: 100, ideal: 130)
            .customizationID("category")

            TableColumn("IANA Name", sortUsing: OpenPortComparator(.iana)) { port in
                OptionalText(port.iana).monospaced()
            }
            .width(min: 90, ideal: 120)
            .customizationID("iana")

            TableColumn("Description", sortUsing: OpenPortComparator(.description)) { port in
                OptionalText(port.distinctDescription)
                    .help(port.distinctDescription ?? "")
            }
            .width(min: 150, ideal: 300)
            .customizationID("description")
        }
        // Stripes behind an empty-state message read as clutter.
        .alternatingRowBackgrounds(model.visiblePorts.isEmpty ? .disabled : .enabled)
        .contextMenu(forSelectionType: UInt16.self) { selection in
            menu(for: selection)
        } primaryAction: { selection in
            openInBrowser(model.visiblePorts.filter { selection.contains($0.port) })
        }
        .onCopyCommand {
            [NSItemProvider(object: ResultExport.tabSeparated(model.selectedPorts) as NSString)]
        }
    }

    @ViewBuilder
    private func menu(for selection: Set<UInt16>) -> some View {
        let ports = model.visiblePorts.filter { selection.contains($0.port) }
        if let host = model.scannedHost, !ports.isEmpty {
            let webPorts = ports.filter(\.isWeb)
            if !webPorts.isEmpty {
                Button("Open in Browser", systemImage: "safari") { openInBrowser(webPorts) }
                Divider()
            }
            Button(ports.count == 1 ? "Copy Address" : "Copy \(ports.count) Addresses") {
                SystemActions.copy(ports.map { "\(host):\($0.port)" }.joined(separator: "\n"))
            }
            Button(ports.count == 1 ? "Copy Row" : "Copy \(ports.count) Rows") {
                SystemActions.copy(ResultExport.tabSeparated(ports))
            }
        }
    }

    private func openInBrowser(_ ports: [OpenPort]) {
        guard let host = model.scannedHost else { return }
        for port in ports where port.isWeb {
            if let url = port.webURL(host: host) { SystemActions.open(url) }
        }
    }
}
