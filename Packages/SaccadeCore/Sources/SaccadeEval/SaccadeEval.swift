import Foundation
import SaccadeCore

/// `saccade-eval`: replays recordings through the production pipeline and reports metrics (F-15,
/// TESTING_GUIDE §5.2).
///
/// - `--trace <file.jsonl>` replays one features-only session trace (`saccade-trace/v2`, recorded with Settings →
///   Advanced → Record sessions for tuning) and prints the error of each pipeline stage at every click label.
///   Drift tunables can be overridden to compare settings on the same recording.
/// - `--dataset` gates (landmark-trace datasets) are not implemented yet (ROADMAP P1.T11) and are refused, so CI
///   can't pass on an empty gate.
public enum SaccadeEval {
    public static let version = "0.2.0"

    public static let usage = """
    Usage: saccade-eval --trace <file.jsonl> [--no-learning] [--kernel <pt>] [--half-life <s>]
                        [--shrinkage <n>] [--global-shrinkage <n>] [--max-offset <pt>]
           saccade-eval --dataset <dir> [--check]        (not implemented yet)
           saccade-eval --help | --version
    """

    /// Exit codes: 0 success, 1 gate failed, 2 usage error or not yet implemented.
    public static func run(arguments: [String], output: (String) -> Void) -> Int32 {
        if arguments.contains("--help") || arguments.contains("-h") {
            output(usage)
            return 0
        }
        if arguments.contains("--version") {
            output("saccade-eval \(version)")
            return 0
        }
        if let path = value(after: "--trace", in: arguments) {
            return replay(path: path, arguments: arguments, output: output)
        }
        if arguments.isEmpty {
            output(usage)
            return 2
        }
        output("saccade-eval: dataset gates are not implemented yet (ROADMAP P1.T11). Use --trace.")
        return 2
    }

    static func replay(path: String, arguments: [String], output: (String) -> Void) -> Int32 {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            output("saccade-eval: can't read \(path)")
            return 2
        }
        let records: [TraceRecord]
        do {
            records = try SessionTrace.decode(text)
        } catch {
            output("saccade-eval: \(path) is not a valid saccade-trace/v2 file")
            return 2
        }
        guard let replay = configure(arguments: arguments) else {
            output(usage)
            return 2
        }
        output(markdown(replay.run(records), title: (path as NSString).lastPathComponent))
        return 0
    }

    /// A replay with tunables from the command line, or `nil` for a malformed number.
    static func configure(arguments: [String]) -> TraceReplay? {
        var replay = TraceReplay()
        replay.learns = !arguments.contains("--no-learning")
        let numeric: [(String, WritableKeyPath<DriftCorrector, Double>)] = [
            ("--kernel", \.kernelRadius), ("--half-life", \.halfLife), ("--shrinkage", \.shrinkage),
            ("--global-shrinkage", \.globalShrinkage), ("--max-offset", \.maxOffset),
        ]
        for (flag, keyPath) in numeric {
            guard let raw = value(after: flag, in: arguments) else { continue }
            guard let number = Double(raw), number.isFinite, number >= 0 else { return nil }
            replay.drift[keyPath: keyPath] = number
        }
        return replay
    }

    /// A Markdown report: errors per stage in points and degrees.
    static func markdown(_ report: TraceReplay.Report, title: String) -> String {
        func cell(_ value: Double?) -> String {
            guard let value else { return "—" }
            let degrees = value / max(report.pointsPerDegree, 1e-9)
            return String(format: "%.0f pt (%.2f°)", value, degrees)
        }
        var lines = [
            "## \(title)",
            "",
            "\(report.frames) frames · \(report.labels) labels · \(report.unmatched) without an estimate",
            "",
            "| Stage | Median | p90 |",
            "|---|---|---|",
        ]
        for (name, stage) in [
            ("Mapper", report.mapper),
            ("Stabilized", report.stabilized),
            ("Corrected (what the user saw)", report.corrected),
        ] {
            lines.append("| \(name) | \(cell(stage.median)) | \(cell(stage.p90)) |")
        }
        return lines.joined(separator: "\n")
    }

    static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
}
