// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "AXSwift",
    products: [
        .library(
            name: "AXSwift",
            targets: ["AXSwift"]),
    ],
    targets: [
        .target(
            name: "AXSwift",
            path: "Sources"),
        .target(name: "AXSwiftExample",
            dependencies: ["AXSwift"],
            path: "AXSwiftExample"),
        .target(name: "AXSwiftObserverExample",
            dependencies: ["AXSwift"],
            path: "AXSwiftObserverExample"),
    ]
)
