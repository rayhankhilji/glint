import Foundation
import SaccadeCore
import Testing
@testable import SaccadeEval

@Suite("saccade-eval CLI")
struct SaccadeEvalTests {
    @Test("--help and --version succeed")
    func helpAndVersion() {
        var out: [String] = []
        #expect(SaccadeEval.run(arguments: ["--help"]) { out.append($0) } == 0)
        #expect(SaccadeEval.run(arguments: ["--version"]) { out.append($0) } == 0)
        #expect(out.last == "saccade-eval \(SaccadeEval.version)")
    }

    @Test("Dataset gates are refused until replay exists, so CI can't pass vacuously")
    func unimplementedGateFails() {
        #expect(SaccadeEval.run(arguments: ["--dataset", "Evals/datasets/ci", "--check"]) { _ in } == 2)
        #expect(SaccadeEval.run(arguments: []) { _ in } == 2)
    }

    @Test("--trace replays a file and prints a per-stage table; tunables parse")
    func traceReplay() throws {
        let header = TraceRecord.header(TraceHeader(screen: Size(width: 1440, height: 900), pointsPerDegree: 40))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("eval-\(UUID().uuidString).jsonl")
        try (SessionTrace.encodeLine(header) + "\n").write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        var out: [String] = []
        #expect(SaccadeEval.run(arguments: ["--trace", url.path, "--kernel", "300"]) { out.append($0) } == 0)
        #expect(out.joined().contains("| Corrected (what the user saw) |"))
        #expect(SaccadeEval.configure(arguments: ["--kernel", "300"])?.drift.kernelRadius == 300)
        #expect(SaccadeEval.configure(arguments: ["--kernel", "abc"]) == nil)
        #expect(SaccadeEval.run(arguments: ["--trace", "/nonexistent.jsonl"]) { _ in } == 2)
    }
}
