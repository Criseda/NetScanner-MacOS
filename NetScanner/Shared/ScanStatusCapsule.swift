import NetScannerKit
import SwiftUI

/// Floating progress for a running scan, over the bottom of the results.
///
/// It is the one piece of custom glass in the app: chrome that floats
/// over content is what Liquid Glass is for.
struct ScanStatusCapsule: View {
    let progress: ScanProgress?
    /// What is being scanned, e.g. "192.168.1.0/24".
    let target: String
    /// The scan is held until the user answers the Local Network prompt.
    var waitingForPermission = false

    var body: some View {
        HStack(spacing: 10) {
            if waitingForPermission {
                ProgressView()
                    .controlSize(.small)
                Text("Waiting for Local Network access…")
                    .lineLimit(1)
            } else if let progress {
                ProgressView(value: progress.fraction)
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                Text("\(progress.phase.label) \(target)")
                    .lineLimit(1)
                Text(progress.countText)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.default, value: progress.done)
            } else {
                ProgressView()
                    .controlSize(.small)
                Text("Starting scan of \(target)…")
                    .lineLimit(1)
            }
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

#Preview {
    VStack(spacing: 20) {
        ScanStatusCapsule(progress: nil, target: "192.168.1.0/24")
        ScanStatusCapsule(progress: nil, target: "192.168.1.0/24", waitingForPermission: true)
        ScanStatusCapsule(
            progress: ScanProgress(phase: .sweep, done: 120, total: 254), target: "192.168.1.0/24")
        ScanStatusCapsule(
            progress: ScanProgress(phase: .identify, done: 3, total: 9), target: "192.168.1.0/24")
    }
    .padding(40)
}
