// swift-tools-version: 6.0
// SaccadeCore: pure, cross-platform (macOS + Linux) logic. Foundation only — see ARCHITECTURE §3 and ADR-004.
import PackageDescription

let package = Package(
    name: "SaccadeCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SaccadeCore", targets: ["SaccadeCore"]),
        .library(name: "SaccadeCoreTestSupport", targets: ["SaccadeCoreTestSupport"]),
        .library(name: "SaccadeEval", targets: ["SaccadeEval"]),
        .executable(name: "saccade-eval", targets: ["saccade-eval"]),
    ],
    targets: [
        .target(name: "SaccadeCore"),
        .target(name: "SaccadeCoreTestSupport", dependencies: ["SaccadeCore"]),
        .target(name: "SaccadeEval", dependencies: ["SaccadeCore"]),
        .executableTarget(name: "saccade-eval", dependencies: ["SaccadeEval"]),
        .testTarget(name: "SaccadeCoreTests", dependencies: ["SaccadeCore", "SaccadeCoreTestSupport"]),
        .testTarget(name: "SaccadeEvalTests", dependencies: ["SaccadeEval", "SaccadeCoreTestSupport"]),
    ],
    swiftLanguageModes: [.v6]
)
