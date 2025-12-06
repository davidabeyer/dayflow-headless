// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DayflowHeadless",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "dayflow-headless",
            targets: ["DayflowHeadless"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.5.0"),
        .package(url: "https://github.com/getsentry/sentry-cocoa", from: "8.0.0")
    ],
    targets: [
        // Main executable
        .executableTarget(
            name: "DayflowHeadless",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Sentry", package: "sentry-cocoa")
            ],
            path: "Sources/DayflowHeadless"
        ),

        // Test targets
        .testTarget(
            name: "DaemonTests",
            dependencies: ["DayflowHeadless"],
            path: "Tests/DaemonTests"
        ),
        .testTarget(
            name: "ConfigTests",
            dependencies: ["DayflowHeadless"],
            path: "Tests/ConfigTests"
        ),
        .testTarget(
            name: "PermissionTests",
            dependencies: ["DayflowHeadless"],
            path: "Tests/PermissionTests"
        ),
        .testTarget(
            name: "LaunchdTests",
            dependencies: ["DayflowHeadless"],
            path: "Tests/LaunchdTests"
        )
    ]
)
