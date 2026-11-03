import Foundation
import SaccadeCoreTestSupport
import Testing
@testable import SaccadeCore

@Suite("Blinks")
struct BlinkTests {
    /// Feeds an openness timeline at 30 fps; returns detected blinks and gestures.
    private func run(_ segments: [(openness: Double, seconds: Double)]) -> ([Blink], [BlinkGrammar.Gesture]) {
        var detector = BlinkDetector()
        var grammar = BlinkGrammar()
        var blinks: [Blink] = []
        var gestures: [BlinkGrammar.Gesture] = []
        var t = 0.0
        for segment in segments {
            let end = t + segment.seconds
            while t < end - 1e-9 {
                grammar.expire(at: t, eyesClosed: detector.isClosed)
                if let blink = detector.ingest(openness: segment.openness, at: t).blink {
                    blinks.append(blink)
                    if let g = grammar.ingest(blink) {
                        gestures.append(g)
                    }
                }
                t += 1.0 / 30
            }
        }
        return (blinks, gestures)
    }

    @Test("T-F02-AC3: a 150 ms closure is exactly one blink")
    func singleBlink() {
        let (blinks, gestures) = run([(0.32, 1), (0.05, 0.15), (0.32, 1)])
        #expect(blinks.count == 1)
        #expect(blinks.first?.kind == .blink)
        #expect(gestures.isEmpty)
    }

    @Test("Two quick blinks are a double blink")
    func doubleBlink() {
        let (_, gestures) = run([(0.32, 1), (0.05, 0.12), (0.32, 0.2), (0.05, 0.12), (0.32, 1)])
        #expect(gestures == [.doubleBlink])
    }

    @Test("Blink then long blink is the right-click gesture")
    func rightClick() {
        let (_, gestures) = run([(0.32, 1), (0.05, 0.12), (0.32, 0.2), (0.05, 0.6), (0.32, 1)])
        #expect(gestures == [.blinkLongBlink])
    }

    @Test("T-F06-AC7: resting eyes (2 s closed) never make a gesture")
    func restingEyes() {
        let (blinks, gestures) = run([(0.32, 1), (0.05, 2), (0.32, 1)])
        #expect(blinks.isEmpty)
        #expect(gestures.isEmpty)
    }

    @Test("Natural blinks 3 s apart are never a double blink")
    func naturalBlinks() {
        var timeline: [(Double, Double)] = [(0.32, 1)]
        for _ in 0 ..< 10 {
            timeline += [(0.05, 0.15), (0.32, 3)]
        }
        let (blinks, gestures) = run(timeline)
        #expect(blinks.count == 10)
        #expect(gestures.isEmpty)
    }

    @Test("The baseline adapts to a squinting user")
    func adaptiveBaseline() {
        let (blinks, gestures) = run([(0.2, 3), (0.03, 0.12), (0.2, 0.2), (0.03, 0.12), (0.2, 1)])
        #expect(blinks.count == 2)
        #expect(gestures == [.doubleBlink])
    }
}

@Suite("Estimator and filter")
struct EstimatorTests {
    @Test("One Euro filter smooths jitter but follows a step")
    func oneEuro() {
        var f = OneEuroFilter()
        var rng = SeededGenerator(seed: 9)
        var out = 0.0
        var t = 0.0
        var spread: [Double] = []
        for _ in 0 ..< 60 {
            out = f.filter(100 + rng.nextGaussian(standardDeviation: 10), at: t)
            spread.append(out)
            t += 1.0 / 30
        }
        let late = spread.suffix(30)
        let mean = late.reduce(0, +) / Double(late.count)
        let sd = (late.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(late.count)).squareRoot()
        #expect(sd < 5, "smoothed sd \(sd)")
        for _ in 0 ..< 60 {
            out = f.filter(600, at: t)
            t += 1.0 / 30
        }
        #expect(abs(out - 600) < 5)
    }

    @Test("T-F02-AC4: no face or low confidence → no point, filter reset")
    func faceLost() {
        var face = SyntheticFace(seed: 4)
        let model = (face.calibrate().phase.result?.model)
        var estimator = GazeEstimator(model: model)
        let good = estimator.ingest(face.observe(target: Point(x: 300, y: 300), t: 0), at: 0)
        #expect(good.point != nil && good.faceVisible)
        let none = estimator.ingest(nil, at: 0.033)
        #expect(none.point == nil && !none.faceVisible)
        var weak = face.observe(target: Point(x: 300, y: 300), t: 0.066)
        weak.confidence = 0.2
        #expect(estimator.ingest(weak, at: 0.066).point == nil)
    }

    @Test("The estimator tracks a calibrated face and reports a double blink")
    func endToEnd() throws {
        var face = SyntheticFace(seed: 8)
        face.pupilNoise = 0.02
        let model = try #require(face.calibrate().phase.result?.model)
        var estimator = GazeEstimator(model: model)
        var t = 0.0
        var last: GazeSample?
        let target = Point(x: 1100, y: 250)
        for _ in 0 ..< 60 {
            last = estimator.ingest(face.observe(target: target, t: t), at: t)
            t += 1.0 / 30
        }
        let point = try #require(last?.point)
        #expect(point.distance(to: target) < 80, "\(point)")
        var gestures: [BlinkGrammar.Gesture] = []
        for (openness, frames) in [(0.04, 4), (0.32, 6), (0.04, 4), (0.32, 10)] {
            for _ in 0 ..< frames {
                if let g = estimator.ingest(face.observe(target: target, t: t, openness: openness), at: t).gesture {
                    gestures.append(g)
                }
                t += 1.0 / 30
            }
        }
        #expect(gestures == [.doubleBlink])
    }
}

extension CalibrationSession.Phase {
    var result: CalibrationResult? {
        if case let .finished(r) = self {
            return r
        }
        return nil
    }
}
