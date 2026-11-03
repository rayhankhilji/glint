// swift-tools-version: 6.0
// GlintKit: macOS-only modules (ARCHITECTURE §3). Pure logic belongs in GlintCore instead.
import PackageDescription

let package = Package(
    name: "GlintKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "GlintPlatform", targets: ["GlintPlatform"]),
        .library(name: "GlintPerception", targets: ["GlintPerception"]),
        .library(name: "GlintSystem", targets: ["GlintSystem"]),
        .library(name: "GlintServices", targets: ["GlintServices"]),
        .library(name: "GlintUI", targets: ["GlintUI"]),
        .library(name: "GlintRuntime", targets: ["GlintRuntime"]),
    ],
    dependencies: [
        .package(path: "../GlintCore"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", exact: "1.19.6"),
    ],
    targets: [
        // Shared macOS kernel: logging, signposts, production clock, app paths (ADR-010).
        .target(name: "GlintPlatform", dependencies: [.product(name: "GlintCore", package: "GlintCore")]),
        .target(name: "GlintPerception", dependencies: [
            .product(name: "GlintCore", package: "GlintCore"), "GlintPlatform",
        ]),
        .target(name: "GlintSystem", dependencies: [
            .product(name: "GlintCore", package: "GlintCore"), "GlintPlatform",
        ]),
        .target(name: "GlintServices", dependencies: [
            .product(name: "GlintCore", package: "GlintCore"), "GlintPlatform",
        ]),
        // No resources: colors are generated Swift (Design/tokens.json) and UI icons are SF Symbols.
        .target(name: "GlintUI", dependencies: [.product(name: "GlintCore", package: "GlintCore"), "GlintPlatform"]),
        .target(name: "GlintRuntime", dependencies: [
            .product(name: "GlintCore", package: "GlintCore"),
            "GlintPlatform", "GlintPerception", "GlintSystem", "GlintServices",
        ]),
        .testTarget(name: "GlintPlatformTests", dependencies: ["GlintPlatform"]),
        .testTarget(name: "GlintServicesTests", dependencies: [
            "GlintServices", .product(name: "GlintCoreTestSupport", package: "GlintCore"),
        ]),
        .testTarget(
            name: "GlintUITests",
            dependencies: [
                "GlintUI", .product(name: "GlintCoreTestSupport", package: "GlintCore"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            exclude: ["__Snapshots__"]
        ),
        .testTarget(name: "GlintRuntimeTests", dependencies: ["GlintRuntime"]),
    ],
    swiftLanguageModes: [.v6]
)
