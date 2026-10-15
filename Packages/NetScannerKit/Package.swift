// swift-tools-version: 6.2

import PackageDescription

/// Everything in the app that is not UI: running the `ns` engine,
/// decoding its events, the models they become, input validation and
/// export. No SwiftUI or AppKit here, so all of it is tested with a
/// plain `swift test`.
let package = Package(
    name: "NetScannerKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "NetScannerKit", targets: ["NetScannerKit"])
    ],
    targets: [
        .target(name: "NetScannerKit", resources: [.process("Resources")]),
        .testTarget(name: "NetScannerKitTests", dependencies: ["NetScannerKit"]),
    ]
)
