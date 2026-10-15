import Foundation
import NetScannerKit

extension ScanEngine {
    /// The engine shipped inside the app, `Contents/Helpers/ns`.
    ///
    /// The app only ever runs this one: a new engine reaches users as a
    /// new app release. Debug builds also honor `NETSCANNER_ENGINE` (set
    /// it in the scheme) to try an engine that is not released yet.
    static var bundled: ScanEngine {
        #if DEBUG
            if let path = ProcessInfo.processInfo.environment["NETSCANNER_ENGINE"], !path.isEmpty {
                return ScanEngine(executableURL: URL(filePath: path))
            }
        #endif
        return ScanEngine(
            executableURL: Bundle.main.bundleURL.appending(path: "Contents/Helpers/ns"))
    }
}
