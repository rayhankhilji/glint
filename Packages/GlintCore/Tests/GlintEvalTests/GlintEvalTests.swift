import Testing
@testable import GlintEval

@Suite("glint-eval CLI")
struct GlintEvalTests {
    @Test("--help and --version succeed")
    func helpAndVersion() {
        var out: [String] = []
        #expect(GlintEval.run(arguments: ["--help"]) { out.append($0) } == 0)
        #expect(GlintEval.run(arguments: ["--version"]) { out.append($0) } == 0)
        #expect(out.last == "glint-eval \(GlintEval.version)")
    }

    @Test("Gates are refused until replay exists, so CI can't pass vacuously")
    func unimplementedGateFails() {
        #expect(GlintEval.run(arguments: ["--dataset", "Evals/datasets/ci", "--check"]) { _ in } == 2)
        #expect(GlintEval.run(arguments: []) { _ in } == 2)
    }
}
