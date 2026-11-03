import Testing
@testable import SaccadeCore

@Suite("Clock and randomness")
struct TimeTests {
    @Test("ManualClock only moves forward")
    func manualClock() {
        let clock = ManualClock(start: 10)
        clock.advance(by: 0.5)
        #expect(clock.now() == 10.5)
        clock.advance(by: -3)
        #expect(clock.now() == 10.5)
        clock.set(5)
        #expect(clock.now() == 10.5)
        clock.set(12)
        #expect(clock.now() == 12)
    }

    @Test("SeededGenerator is deterministic and seed-dependent")
    func seededDeterminism() {
        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        var c = SeededGenerator(seed: 43)
        let seqA = (0 ..< 5).map { _ in a.next() }
        let seqB = (0 ..< 5).map { _ in b.next() }
        let seqC = (0 ..< 5).map { _ in c.next() }
        #expect(seqA == seqB)
        #expect(seqA != seqC)
    }

    @Test("SplitMix64 matches the reference output for seed 0")
    func splitMixReference() {
        var gen = SeededGenerator(seed: 0)
        #expect(gen.next() == 0xE220_A839_7B1D_CDAF)
        #expect(gen.next() == 0x6E78_9E6A_A1B9_65F4)
    }

    @Test("Unit samples stay in [0, 1) and gaussian samples have the right moments")
    func distributions() {
        var gen = SeededGenerator(seed: 7)
        let units = (0 ..< 10000).map { _ in gen.nextUnit() }
        #expect(units.allSatisfy { $0 >= 0 && $0 < 1 })
        let normals = (0 ..< 20000).map { _ in gen.nextGaussian(mean: 3, standardDeviation: 2) }
        let mean = normals.reduce(0, +) / Double(normals.count)
        let variance = normals.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(normals.count)
        #expect(abs(mean - 3) < 0.05)
        #expect(abs(variance.squareRoot() - 2) < 0.05)
    }
}
