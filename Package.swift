// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "InitSignal",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .macCatalyst(.v16),
    ],
    products: [
        .library(
            name: "InitSignal",
            targets: ["InitSignal"]
        ),
    ],
    targets: [
        .target(
            name: "InitSignal",
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
        .testTarget(
            name: "InitSignalTests",
            dependencies: ["InitSignal"]
        ),
    ]
)
