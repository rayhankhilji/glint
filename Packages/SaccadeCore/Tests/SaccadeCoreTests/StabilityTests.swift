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

    @Test("A few clicks remove a posture offset where they happened and mostly everywhere else")
    func driftCorrection() {
        var d = DriftCorrector()
        let offset = Point(x: 60, y: -40)
        for i in 0 ..< 4 {
            let truth = Point(x: 300 + Double(i) * 30, y: 300)
            d.learn(estimate: truth - offset, truth: truth, at: Double(i))
        }
        let local = d.correction(at: Point(x: 330, y: 310), now: 5)
        #expect(local.distance(to: offset) < 8, "\(local)")
        // The global shift carries to the far corner, shrunk until more labels agree.
        let far = d.correction(at: Point(x: 1400, y: 850), now: 5)
        #expect(far.distance(to: offset) < offset.length * 0.45, "\(far)")
        #expect(far.length < offset.length, "\(far)")
    }

    @Test("One shift after a head move: clicks in two corners fix the opposite corners too")
    func globalShift() {
        var d = DriftCorrector()
        let offset = Point(x: -45, y: 35)
        for (i, truth) in [
            Point(x: 200, y: 150),
            Point(x: 1300, y: 800),
            Point(x: 220, y: 170),
            Point(x: 1280, y: 780),
            Point(x: 210, y: 160),
            Point(x: 1290, y: 790),
        ].enumerated() {
            d.learn(estimate: truth - offset, truth: truth, at: Double(i))
        }
        let elsewhere = d.correction(at: Point(x: 1300, y: 150), now: 7)
        #expect(elsewhere.distance(to: offset) < 15, "\(elsewhere)")
    }

    @Test("Position-dependent errors are kept local on top of the shift")
    func localPattern() {
        var d = DriftCorrector()
        for i in 0 ..< 6 {
            let left = Point(x: 150, y: 200 + Double(i) * 80)
            let right = Point(x: 1350, y: 200 + Double(i) * 80)
            d.learn(estimate: left - Point(x: 50, y: 0), truth: left, at: Double(i))
            d.learn(estimate: right - Point(x: -50, y: 0), truth: right, at: Double(i))
        }
        #expect(d.correction(at: Point(x: 150, y: 400), now: 7).x > 35)
        #expect(d.correction(at: Point(x: 1350, y: 400), now: 7).x < -35)
        #expect(abs(d.correction(at: Point(x: 750, y: 400), now: 7).x) < 15)
    }

    @Test("Corrections learned in one sitting position don't apply in another")
    func poseGating() {
        var d = DriftCorrector()
        let here = HeadPose(faceX: 0.5, faceY: 0.45, faceScale: 0.3)
        let moved = HeadPose(faceX: 0.65, faceY: 0.45, faceScale: 0.3)
        let offset = Point(x: 70, y: 0)
        for i in 0 ..< 6 {
            let truth = Point(x: 400 + Double(i) * 40, y: 400)
            d.learn(estimate: truth - offset, truth: truth, at: Double(i), pose: here)
        }
        #expect(d.correction(at: Point(x: 500, y: 400), now: 7, pose: here).x > 55)
        // 3 σ of head movement away: at most a small remnant applies.
        #expect(d.correction(at: Point(x: 500, y: 400), now: 7, pose: moved).length < offset.length * 0.15)
        #expect(here.similarity(to: here) == 1)
    }

    @Test("Live accuracy: the corrected error at each click, once there are five")
    func liveAccuracy() {
        var d = DriftCorrector()
        let offset = Point(x: 30, y: 0)
        for i in 0 ..< 4 {
            let truth = Point(x: 500 + Double(i) * 10, y: 500)
            d.learn(estimate: truth - offset, truth: truth, at: Double(i))
        }
        #expect(d.liveErrorPoints == nil)
        for i in 4 ..< 10 {
            let truth = Point(x: 500 + Double(i) * 10, y: 500)
            d.learn(estimate: truth - offset, truth: truth, at: Double(i))
        }
        let live = d.liveErrorPoints ?? .infinity
        #expect(live < 12, "\(live)") // the first click saw the full 30 pt; later ones see what's left
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
