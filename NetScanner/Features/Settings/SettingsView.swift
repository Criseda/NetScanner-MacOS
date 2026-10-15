import NetScannerKit
import SwiftUI

/// The Settings window (⌘,).
struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettings()
            }
            Tab("About", systemImage: "info.circle") {
                AboutSettings()
            }
        }
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct GeneralSettings: View {
    @AppStorage(PortScanDefaults.rangeKey) private var range = PortScanDefaults.range
    @AppStorage(PortScanDefaults.timeoutKey) private var timeout = ""

    var body: some View {
        Form {
            Section {
                ValidatedField(
                    "Default ports", text: $range, prompt: PortScanDefaults.range,
                    validate: { (text) throws(InputError) in try PortRange(validating: text) })
                ValidatedField(
                    "Timeout per port", text: $timeout, prompt: String(localized: "Automatic"),
                    validate: { (text) throws(InputError) in try ProbeTimeout.parse(text) })
            } header: {
                Text("Port Scan")
            } footer: {
                Text("Leave the timeout empty to let NetScanner learn the right wait from each host’s answers (100–500 ms). Set one in milliseconds only for links slower than that.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// A text field that only commits values `validate` accepts, and says
/// why when it does not.
private struct ValidatedField<Value>: View {
    let title: LocalizedStringKey
    @Binding var text: String
    let prompt: String
    let validate: (String) throws(InputError) -> Value

    @State private var draft = ""
    @State private var error: InputError?

    init(
        _ title: LocalizedStringKey, text: Binding<String>, prompt: String,
        validate: @escaping (String) throws(InputError) -> Value
    ) {
        self.title = title
        _text = text
        self.prompt = prompt
        self.validate = validate
    }

    var body: some View {
        LabeledContent(title) {
            VStack(alignment: .trailing, spacing: 4) {
                TextField(title, text: $draft, prompt: Text(prompt))
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(maxWidth: 160)
                if let error {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .onAppear { draft = text }
        .onChange(of: draft) {
            do throws(InputError) {
                _ = try validate(draft)
                error = nil
                text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                self.error = error
            }
        }
    }
}

private struct AboutSettings: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NetScanner").font(.title2.bold())
                        Text("Fast LAN discovery and port scanning, no administrator rights needed.")
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Version", value: Bundle.main.versionDescription)
                LabeledContent("Scan engine", value: engineDescription)
            }

            Section {
                Text("NetScanner is free software under the GNU GPL-3.0. You may run, study, share and modify it; if you distribute it, provide the source under the same license.")
                    .foregroundStyle(.secondary)
                Link("NetScanner on GitHub", destination: URL(string: "https://github.com/Criseda/NetScanner")!)
                Link("GNU GPL-3.0", destination: URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!)
            }
        }
        .formStyle(.grouped)
    }

    private var engineDescription: String {
        switch app.engineStatus {
        case .checking: String(localized: "Checking…")
        case .ready(let version): "ns \(version)"
        case .unavailable: String(localized: "Unavailable")
        }
    }
}

extension Bundle {
    /// "0.1.0 (1)"
    fileprivate var versionDescription: String {
        let version = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }
}
