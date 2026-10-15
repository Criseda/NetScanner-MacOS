import SwiftUI

/// The main window: a sidebar of scan types and the selected screen.
struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            List(AppModel.Section.allCases, selection: $model.section.optional) { section in
                Label(String(localized: section.title), systemImage: section.symbolName)
                    .badge(badge(for: section))
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 240)
        } detail: {
            Group {
                switch model.section {
                case .discovery: DiscoveryView()
                case .portScan: PortScanView()
                }
            }
            .frame(minWidth: 620, minHeight: 380)
        }
    }

    /// The result count next to each screen's name.
    private func badge(for section: AppModel.Section) -> Int {
        switch section {
        case .discovery: model.discovery.hostCount
        case .portScan: model.portScan.portCount
        }
    }
}

extension Binding where Value: Sendable {
    /// Adapts a non-optional selection to `List(selection:)`, which wants
    /// an optional; deselecting keeps the current value.
    fileprivate var optional: Binding<Value?> {
        Binding<Value?>(
            get: { wrappedValue },
            set: { if let newValue = $0 { wrappedValue = newValue } })
    }
}
