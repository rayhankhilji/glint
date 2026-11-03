// swift-tools-version: 6.0
// SaccadeKit: macOS-only modules (ARCHITECTURE §3). Pure logic belongs in SaccadeCore instead.
import PackageDescription

let package = Package(
    name: "SaccadeKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SaccadePlatform", targets: ["SaccadePlatform"]),
        .library(name: "SaccadePerception", targets: ["SaccadePerception"]),
        .library(name: "SaccadeSystem", targets: ["SaccadeSystem"]),
        .library(name: "SaccadeServices", targets: ["SaccadeServices"]),
        .library(name: "SaccadeUI", targets: ["SaccadeUI"]),
        .library(name: "SaccadeRuntime", targets: ["SaccadeRuntime"]),
    ],
    dependencies: [
        .package(path: "../SaccadeCore"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", exact: "1.19.6"),
    ],
    targets: [
        // Shared macOS kernel: logging, signposts, production clock, app paths (ADR-010).
        .target(name: "SaccadePlatform", dependencies: [.product(name: "SaccadeCore", package: "SaccadeCore")]),
        .target(name: "SaccadePerception", dependencies: [
            .product(name: "SaccadeCore", package: "SaccadeCore"), "SaccadePlatform",
        ]),
        .target(name: "SaccadeSystem", dependencies: [
            .product(name: "SaccadeCore", package: "SaccadeCore"), "SaccadePlatform",
        ]),
        .target(name: "SaccadeServices", dependencies: [
            .product(name: "SaccadeCore", package: "SaccadeCore"), "SaccadePlatform",
        ]),
        // No resources: colors are generated Swift (Design/tokens.json) and UI icons are SF Symbols.
        .target(
            name: "SaccadeUI",
            dependencies: [.product(name: "SaccadeCore", package: "SaccadeCore"), "SaccadePlatform"]
        ),
        .target(name: "SaccadeRuntime", dependencies: [
            .product(name: "SaccadeCore", package: "SaccadeCore"),
            "SaccadePlatform", "SaccadePerception", "SaccadeServices",
        ]),
        .testTarget(name: "SaccadePlatformTests", dependencies: ["SaccadePlatform"]),
        .testTarget(name: "SaccadeServicesTests", dependencies: [
            "SaccadeServices", .product(name: "SaccadeCoreTestSupport", package: "SaccadeCore"),
        ]),
        .testTarget(
            name: "SaccadeUITests",
            dependencies: [
                "SaccadeUI", .product(name: "SaccadeCoreTestSupport", package: "SaccadeCore"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            exclude: ["__Snapshots__"]
        ),
        .testTarget(name: "SaccadeRuntimeTests", dependencies: [
            "SaccadeRuntime", .product(name: "SaccadeCoreTestSupport", package: "SaccadeCore"),
        ]),
    ],
    swiftLanguageModes: [.v6]
)
