// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "AXSwift6",
    platforms: [
        .macOS("26.0"),
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
        .testTarget(
            name: "AXSwift6Tests",
            dependencies: ["AXSwift6"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
