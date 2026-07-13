// swift-tools-version:6.4

import PackageDescription

let package = Package(
    name: "AXSwift6",
    platforms: [
        .macOS(.v27),
    ],
    products: [
        .library(
            name: "AXSwift6",
            targets: ["AXSwift6"]
        ),
    ],
    targets: [
        .target(
            name: "AXSwift6",
            path: "Sources"
        ),
    ],
    swiftLanguageModes: [.v5]
)
