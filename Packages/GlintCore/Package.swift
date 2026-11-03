// swift-tools-version: 6.0
// GlintCore: pure, cross-platform (macOS + Linux) logic. Foundation only — see ARCHITECTURE §3 and ADR-004.
import PackageDescription

let package = Package(
    name: "GlintCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "GlintCore", targets: ["GlintCore"]),
        .library(name: "GlintCoreTestSupport", targets: ["GlintCoreTestSupport"]),
        .library(name: "GlintEval", targets: ["GlintEval"]),
        .executable(name: "glint-eval", targets: ["glint-eval"]),
    ],
    targets: [
        .target(name: "GlintCore"),
        .target(name: "GlintCoreTestSupport", dependencies: ["GlintCore"]),
        .target(name: "GlintEval", dependencies: ["GlintCore"]),
        .executableTarget(name: "glint-eval", dependencies: ["GlintEval"]),
        .testTarget(name: "GlintCoreTests", dependencies: ["GlintCore", "GlintCoreTestSupport"]),
        .testTarget(name: "GlintEvalTests", dependencies: ["GlintEval", "GlintCoreTestSupport"]),
    ],
    swiftLanguageModes: [.v6]
)
