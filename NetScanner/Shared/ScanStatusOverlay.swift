import SwiftUI

/// The floating status capsule at the bottom of a results table, shown
/// while a scan waits for Local Network access or runs.
///
/// It animates on its own, so results and empty states underneath swap
/// instantly instead of cross-fading with it.
struct ScanStatusOverlay: View {
    let activity: ScanActivity
    /// What is being scanned, e.g. "192.168.1.0/24".
    let target: String
    let isWaitingForPermission: Bool

    var body: some View {
        ZStack {
            if isWaitingForPermission {
                capsule(ScanStatusCapsule(progress: nil, target: target, waitingForPermission: true))
            } else if case .running(let progress) = activity.state {
                capsule(ScanStatusCapsule(progress: progress, target: target))
            }
        }
        .animation(.smooth, value: activity.isRunning || isWaitingForPermission)
    }

    private func capsule(_ content: ScanStatusCapsule) -> some View {
        content
            .padding(.bottom, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
