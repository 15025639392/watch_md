// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WatchHikingApp",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11),
        .macOS(.v15)
    ],
    products: [
        .library(name: "HikingCore", targets: ["HikingCore"])
    ],
    targets: [
        .target(
            name: "HikingCore",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "HikingCoreTests",
            dependencies: ["HikingCore"],
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
