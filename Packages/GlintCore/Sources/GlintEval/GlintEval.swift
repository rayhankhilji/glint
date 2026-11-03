import Foundation
import GlintCore

/// `glint-eval`: replays landmark traces through the production pipeline and reports metrics (F-15,
/// TESTING_GUIDE §5.2). The replay engine arrives in P1.T11 and the metric gates in P2.T8; until then the tool
/// only answers `--help` and `--version`, and refuses everything else so CI can't pass on an empty gate.
public enum GlintEval {
    public static let version = "0.1.0"

    public static let usage = """
    Usage: glint-eval --dataset <dir> [--check] [--report <file.md>] [--by-subgroup] [--update-baseline]
           glint-eval --help | --version
    """

    /// Exit codes: 0 success, 1 gate failed, 2 usage error or not yet implemented.
    public static func run(arguments: [String], output: (String) -> Void) -> Int32 {
        if arguments.contains("--help") || arguments.contains("-h") {
            output(usage)
            return 0
        }
        if arguments.contains("--version") {
            output("glint-eval \(version)")
            return 0
        }
        if arguments.isEmpty {
            output(usage)
            return 2
        }
        output("glint-eval: trace replay is not implemented yet (ROADMAP P1.T11).")
        return 2
    }
}
