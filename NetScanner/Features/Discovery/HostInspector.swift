import NetScannerKit
import SwiftUI

/// Details of the selected host, in the window's inspector.
struct HostInspector: View {
    let hosts: [DiscoveredHost]
    let scanPorts: (IPv4) -> Void

    var body: some View {
        switch hosts.count {
        case 0:
            ContentUnavailableView(
                "No Selection", systemImage: "cursorarrow.click",
                description: Text("Select a host to see its details."))
        case 1:
            HostDetails(host: hosts[0], scanPorts: scanPorts)
        default:
            ContentUnavailableView("\(hosts.count) Hosts Selected", systemImage: "square.stack.3d.up")
        }
    }
}

private struct HostDetails: View {
    let host: DiscoveredHost
    let scanPorts: (IPv4) -> Void

    var body: some View {
        Form {
            Section {
                VStack(spacing: 6) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 36))
                        .foregroundStyle(.tint)
                        .padding(.bottom, 4)
                    Text(host.displayName)
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                    if host.hostname != nil {
                        Text(host.ip.description)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity)
                .textSelection(.enabled)
            }

            Section("Device") {
                row("IP Address", host.ip.description)
                row("Name", host.hostname)
                row("Manufacturer", host.vendor)
                row("MAC Address", host.macAddress)
                row("Found Via", host.source.label)
                LabeledContent("Found At") {
                    Text(host.foundAt, format: .dateTime.hour().minute().second())
                }
            }

            Section("Open Ports") {
                if let ports = host.openPorts {
                    if ports.isEmpty {
                        Text("No open ports found.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(ports) { port in
                        PortRow(port: port, host: host.ip)
                    }
                    Button("Scan Again", systemImage: "arrow.clockwise") { scanPorts(host.ip) }
                } else {
                    Text("Not scanned yet.")
                        .foregroundStyle(.secondary)
                    Button("Scan Ports", systemImage: "door.left.hand.open") { scanPorts(host.ip) }
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func row(_ title: LocalizedStringKey, _ value: String?) -> some View {
        if let value {
            LabeledContent(title) {
                Text(value).textSelection(.enabled)
            }
        }
    }
}

private struct PortRow: View {
    let port: OpenPort
    let host: IPv4

    var body: some View {
        LabeledContent {
            if port.isWeb, let url = port.webURL(host: host) {
                Link(destination: url) {
                    Image(systemName: "arrow.up.forward.app")
                }
                .help("Open \(url.absoluteString)")
            }
        } label: {
            Label {
                Text(port.service ?? String(localized: "Unknown service"))
                Text(verbatim: "\(port.port)").monospacedDigit()
            } icon: {
                Image(systemName: port.category?.symbolName ?? "questionmark.circle")
            }
        }
    }
}
