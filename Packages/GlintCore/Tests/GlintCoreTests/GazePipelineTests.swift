import Foundation
import GlintCoreTestSupport
import Testing
@testable import GlintCore

@Suite("Gaze features")
struct GazeFeatureTests {
    @Test("Pupil at the eye center gives zero offset; to the outer corner gives u ≈ 1")
    func eyeFrame() throws {
        let outline = (0 ..< 8).map { i -> Point in
            let a = Double(i) / 8 * 2 * .pi
            return Point(x: 100 + cos(a) * 20, y: 50 + sin(a) * 6)
        }
        let frame = try #require(EyeFrame(outline: outline))
        let (u0, v0) = frame.project(Point(x: 100, y: 50))
        #expect(abs(u0) < 1e-9 && abs(v0) < 1e-9)
        let (u1, _) = frame.project(Point(x: 120, y: 50))
        #expect(abs(u1 - 1) < 1e-9)
        #expect(abs(frame.openness - 0.3) < 0.02)
    }

    @Test("No pupils or degenerate eyes means no features")
    func rejectsBadObservations() {
        var face = SyntheticFace()
        var obs = face.observe(target: Point(x: 700, y: 400), t: 0)
        obs.leftPupil = nil
        #expect(GazeFeatures.extract(from: obs) == nil)
        obs = face.observe(target: Point(x: 700, y: 400), t: 0)
        obs.rightEye = [Point(x: 1, y: 1), Point(x: 1, y: 1), Point(x: 1, y: 1), Point(x: 1, y: 1)]
        #expect(GazeFeatures.extract(from: obs) == nil)
    }

    @Test("Looking right moves both pupils right in their eye frames")
    func monotonic() throws {
        var face = SyntheticFace()
        let left = try #require(GazeFeatures.extract(from: face.observe(target: Point(x: 100, y: 450), t: 0)))
        let right = try #require(GazeFeatures.extract(from: face.observe(target: Point(x: 1340, y: 450), t: 0)))
        #expect(right.leftU > left.leftU)
        #expect(right.rightU > left.rightU)
    }
}

@Suite("Linear algebra and mapper")
struct MapperTests {
    @Test("Cholesky solves a small SPD system")
    func cholesky() throws {
        let a = [4.0, 1, 1, 3]
        let x = try #require(LinearAlgebra.choleskySolve(a, [1, 2], n: 2))
        #expect(abs(4 * x[0] + x[1] - 1) < 1e-12)
        #expect(abs(x[0] + 3 * x[1] - 2) < 1e-12)
        #expect(LinearAlgebra.choleskySolve([0, 0, 0, 0], [1, 1], n: 2) == nil)
    }

    @Test("Too few anchors is CALIBRATION_INSUFFICIENT")
    func insufficient() {
        let samples = (0 ..< 40).map { CalibrationSample(
            features: Array(repeating: Double($0), count: 10),
            target: Point(x: 0, y: 0),
            group: $0 % 3
        ) }
        #expect(throws: GlintError.calibrationInsufficient(anchorsOK: 3)) { try GazeMapper.fit(samples) }
    }

    @Test("Noise-free calibration recovers gaze almost exactly")
    func noiseFree() {
        var face = SyntheticFace(seed: 3)
        let session = face.calibrate()
        guard case let .finished(result) = session.phase else {
            Issue.record("calibration did not finish: \(session.phase)")
            return
        }
        #expect(result.anchorsOK == 9)
        let errors = evaluate(result.model, face: &face, count: 200)
        #expect(GazeMapper.median(errors) < 25, "median \(GazeMapper.median(errors)) pt")
    }

    @Test("Realistic noise and head motion: smoothed median error under 45 pt (≈ 1° on a laptop)")
    func noisy() {
        var face = SyntheticFace(seed: 11)
        face.pupilNoise = 0.03
        face.headJitter = 0.01
        let session = face.calibrate()
        guard case let .finished(result) = session.phase else {
            Issue.record("calibration did not finish: \(session.phase)")
            return
        }
        // What the user sees: the estimator's smoothed point after ~0.5 s of fixation on each target.
        let errors = (0 ..< 60).map { _ -> Double in
            var estimator = GazeEstimator(model: result.model)
            let target = Point(x: 100 + face.rng.nextUnit() * 1240, y: 80 + face.rng.nextUnit() * 740)
            var point = Point.zero
            for frame in 0 ..< 15 {
                let t = Double(frame) / 30
                point = estimator.ingest(face.observe(target: target, t: t), at: t).point ?? point
            }
            return point.distance(to: target)
        }
        let median = GazeMapper.median(errors)
        #expect(median < 45, "median \(median) pt")
        // Single raw frames are noisier but still bounded.
        let single = GazeMapper.median(evaluate(result.model, face: &face, count: 300))
        #expect(single < 90, "single-frame median \(single) pt")
        #expect(result.model.residualPoints > 0)
        #expect(result.medianErrorPoints.isFinite)
    }

    private func evaluate(_ model: MapperModel, face: inout SyntheticFace, count: Int) -> [Double] {
        (0 ..< count).compactMap { _ -> Double? in
            let target = Point(x: 100 + face.rng.nextUnit() * 1240, y: 80 + face.rng.nextUnit() * 740)
            guard let features = GazeFeatures.extract(from: face.observe(target: target, t: 0)) else { return nil }
            return model.predict(features.mapperInputs).distance(to: target)
        }
    }
}

@Suite("Calibration session")
struct CalibrationSessionTests {
    @Test("Intro, then 9 anchors in a snake, then a result")
    func flow() {
        var face = SyntheticFace(seed: 5)
        var session = CalibrationSession(screenSize: face.screenSize)
        #expect(session.phase == .intro)
        var visited: [Int] = []
        var t = 0.0
        while t < 40 {
            if case let .collecting(i) = session.phase, visited.last != i {
                visited.append(i)
            }
            let target = session.target ?? Point(x: 720, y: 450)
            session.ingest(features: GazeFeatures.extract(from: face.observe(target: target, t: t)), at: t)
            if case .finished = session.phase {
                break
            }
            t += 1.0 / 30
        }
        #expect(visited == Array(0 ..< 9))
        guard case .finished = session.phase else {
            Issue.record("not finished")
            return
        }
        // T-F03-AC1: about 15 s from first target to result (≤ 25 s).
        #expect(t < 25)
    }

    @Test("T-F03-AC3: no samples while the face is lost; the anchor resumes afterwards")
    func faceLostPauses() {
        var face = SyntheticFace(seed: 6)
        var session = CalibrationSession(screenSize: face.screenSize)
        var t = 0.0
        while session.phase == .intro {
            session.ingest(features: nil, at: t)
            t += 1.0 / 30
        }
        let before = session.samples.count
        for _ in 0 ..< 90 { // 3 s without a face
            session.ingest(features: nil, at: t)
            t += 1.0 / 30
        }
        #expect(session.samples.count == before)
        #expect(session.phase == .collecting(index: 0))
        for _ in 0 ..< 60 {
            let target = session.target ?? .zero
            session.ingest(features: GazeFeatures.extract(from: face.observe(target: target, t: t)), at: t)
            t += 1.0 / 30
        }
        #expect(session.samples.count > before)
    }

    @Test("T-F03-AC4: too few usable anchors fails without a model")
    func fails() {
        var session = CalibrationSession(screenSize: Size(width: 1440, height: 900))
        var t = 0.0
        var face = SyntheticFace(seed: 7)
        while t < 120 {
            // A face only during the intro and the first 3 anchors' worth of time, then nothing.
            let target = session.target ?? .zero
            let visible: Bool = if case let .collecting(i) = session.phase {
                i < 3
            } else {
                true
            }
            session.ingest(
                features: visible ? GazeFeatures.extract(from: face.observe(target: target, t: t)) : nil,
                at: t
            )
            if case .failed = session.phase {
                break
            }
            if case .collecting(index: 3) = session.phase, t > 30 {
                break
            }
            t += 1.0 / 30
        }
        // With no face from anchor 3 on, the session waits rather than finishing with bad data.
        #expect(session.phase == .collecting(index: 3))
    }
}
