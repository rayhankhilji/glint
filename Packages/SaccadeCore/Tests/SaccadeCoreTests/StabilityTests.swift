import Foundation
import SaccadeCoreTestSupport
import Testing
@testable import SaccadeCore

@Suite("Fixation stabilizer and drift correction")
struct StabilityTests {
    @Test("During a fixation, jitter collapses toward the true point (√n averaging)")
    func fixationAveraging() {
        var s = FixationStabilizer()
        var rng = SeededGenerator(seed: 3)
        let truth = Point(x: 500, y: 400)
        var out = Point.zero
        var t = 0.0
        for _ in 0 ..< 30 {
            let noisy = truth + Point(
                x: rng.nextGaussian(standardDeviation: 18),
                y: rng.nextGaussian(standardDeviation: 18)
            )
            out = s.ingest(noisy, sigma: 40, at: t)
            t += 1.0 / 30
        }
        #expect(out.distance(to: truth) < 8, "\(out)")
        #expect(s.isFixating(at: t))
    }

    @Test("A saccade is followed within two frames; a single outlier is ignored")
    func saccade() {
        var s = FixationStabilizer()
        var t = 0.0
        for _ in 0 ..< 10 {
            _ = s.ingest(Point(x: 100, y: 100), sigma: 30, at: t)
            t += 1.0 / 30
        }
        // One stray frame: held.
        #expect(s.ingest(Point(x: 900, y: 100), sigma: 30, at: t).distance(to: Point(x: 100, y: 100)) < 1)
        t += 1.0 / 30
        #expect(s.ingest(Point(x: 100, y: 100), sigma: 30, at: t).distance(to: Point(x: 100, y: 100)) < 1)
        t += 1.0 / 30
        // A real jump: followed on the second frame.
        _ = s.ingest(Point(x: 900, y: 600), sigma: 30, at: t)
        t += 1.0 / 30
        #expect(s.ingest(Point(x: 900, y: 600), sigma: 30, at: t) == Point(x: 900, y: 600))
        #expect(!s.isFixating(at: t))
    }

    @Test("A few clicks remove a posture offset locally, but not on the other side of the screen")
    func driftCorrection() {
        var d = DriftCorrector()
        let offset = Point(x: 60, y: -40)
        for i in 0 ..< 4 {
            let truth = Point(x: 300 + Double(i) * 30, y: 300)
            d.learn(estimate: truth - offset, truth: truth, at: Double(i))
        }
        let local = d.correction(at: Point(x: 330, y: 310), now: 5)
        #expect(local.distance(to: offset) < 20, "\(local)")
        let far = d.correction(at: Point(x: 1400, y: 850), now: 5)
        #expect(far.length < 5, "\(far)")
    }

    @Test("Implausible labels (looking elsewhere) are ignored; old labels fade")
    func driftSafety() {
        var d = DriftCorrector()
        d.learn(estimate: Point(x: 100, y: 100), truth: Point(x: 900, y: 700), at: 0)
        #expect(d.residuals.isEmpty)
        d.learn(estimate: Point(x: 100, y: 100), truth: Point(x: 150, y: 100), at: 0)
        let fresh = d.correction(at: Point(x: 100, y: 100), now: 0).length
        let old = d.correction(at: Point(x: 100, y: 100), now: 3600).length
        #expect(old < fresh / 4)
    }

    @Test("End to end: a biased calibration gets fixed by mouse clicks")
    func estimatorLearns() throws {
        var face = SyntheticFace(seed: 31)
        face.pupilNoise = 0.02
        guard case let .finished(result) = face.calibrate().phase else {
            Issue.record("no calibration")
            return
        }
        // Simulate a posture change: the user moved, shifting every estimate by a constant.
        var model = result.model
        model.coefX[0] += 70
        model.coefY[0] -= 50
        var estimator = GazeEstimator(model: model)
        var t = 0.0
        func look(at target: Point, frames: Int = 20) -> Point? {
            var p: Point?
            for _ in 0 ..< frames {
                p = estimator.ingest(face.observe(target: target, t: t), at: t).point
                t += 1.0 / 30
            }
            return p
        }
        let probe = Point(x: 700, y: 450)
        let before = try #require(look(at: probe)).distance(to: probe)
        for target in [Point(x: 600, y: 400), Point(x: 800, y: 500), Point(x: 700, y: 350), Point(x: 650, y: 520)] {
            _ = look(at: target)
            estimator.learn(truth: target, at: t) // a mouse click there
        }
        let after = try #require(look(at: probe)).distance(to: probe)
        #expect(before > 60, "before \(before)")
        #expect(after < before / 2.5, "after \(after) vs before \(before)")
    }
}
