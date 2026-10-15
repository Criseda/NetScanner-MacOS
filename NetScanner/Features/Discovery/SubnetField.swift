import NetScannerKit
import SwiftUI

/// The subnet to discover, with this Mac's own networks one click away.
struct SubnetField: View {
    @Binding var text: String
    let error: InputError?
    let networks: [LocalNetwork]
    let refreshNetworks: () -> Void
    let submit: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Menu {
                Section("This Mac’s Networks") {
                    ForEach(networks) { network in
                        Button("\(network.subnet.description) — \(network.displayName)") {
                            text = network.subnet.description
                        }
                    }
                }
                if networks.isEmpty {
                    Text("No networks connected")
                }
            } label: {
                Label("Networks", systemImage: "network")
            }
            .menuIndicator(.hidden)
            .labelStyle(.iconOnly)
            .fixedSize()
            .help("Choose one of this Mac’s networks")
            .onAppear(perform: refreshNetworks)

            TextField("Subnet", text: $text, prompt: Text(verbatim: "192.168.1.0/24"))
                .accessibilityLabel("Subnet")
                .textFieldStyle(.plain)
                .monospacedDigit()
                .frame(width: 140)
                .onSubmit(submit)
                .accessibilityHint("CIDR notation, for example 192.168.1.0/24")

            if let error, !text.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.multicolor)
                    .help(error.localizedDescription)
                    .accessibilityLabel(error.localizedDescription)
            }
        }
        .padding(.horizontal, 8)
    }
}
