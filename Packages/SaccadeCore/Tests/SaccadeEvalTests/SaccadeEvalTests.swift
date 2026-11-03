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

    @Test("Gates are refused until replay exists, so CI can't pass vacuously")
    func unimplementedGateFails() {
        #expect(SaccadeEval.run(arguments: ["--dataset", "Evals/datasets/ci", "--check"]) { _ in } == 2)
        #expect(SaccadeEval.run(arguments: []) { _ in } == 2)
    }
}
