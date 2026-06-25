// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "InitSignal",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .macCatalyst(.v15),
    ],
    products: [
        .library(
            name: "InitSignal",
            targets: ["InitSignal"]
        ),
    ],
    targets: [
        .target(name: "InitSignal"),
        .testTarget(
            name: "InitSignalTests",
            dependencies: ["InitSignal"]
        ),
    ]
)

