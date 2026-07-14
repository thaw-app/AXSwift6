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
        .executable(
            name: "AXSwiftExample",
            targets: ["AXSwiftExample"]
        ),
        .executable(
            name: "AXSwiftObserverExample",
            targets: ["AXSwiftObserverExample"]
        ),
    ],
    targets: [
        .target(
            name: "AXSwift6"
        ),
        .executableTarget(
            name: "AXSwiftExample",
            dependencies: ["AXSwift6"],
            path: "Examples/AXSwiftExample"
        ),
        .executableTarget(
            name: "AXSwiftObserverExample",
            dependencies: ["AXSwift6"],
            path: "Examples/AXSwiftObserverExample"
        ),
        .testTarget(
            name: "AXSwift6Tests",
            dependencies: ["AXSwift6"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
