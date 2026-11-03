import Foundation
import SaccadeCoreTestSupport
import Testing
@testable import SaccadeCore

@Suite("Session traces and replay")
struct TraceTests {
    /// A session with a posture offset: the user clicks around a few targets, dwelling on each.
    static func session(seed: UInt64 = 7) throws -> [TraceRecord] {
        var face = SyntheticFace(seed: seed)
        face.pupilNoise = 0.02
        guard case let .finished(result) = face.calibrate().phase else {
            throw TraceTestError.noCalibration
        }
        var model = result.model
        model.coefX[0] += 60 // posture changed after calibration
        model.coefY[0] -= 45
        var records: [TraceRecord] = [
            .header(TraceHeader(screen: face.screenSize, pointsPerDegree: 40)),
            .model(model),
        ]
        var t = 0.0
        let targets = (0 ..< 24).map { i in
            Point(x: 200 + Double((i * 7) % 11) * 100, y: 150 + Double((i * 5) % 7) * 100)
        }
        for target in targets {
            for _ in 0 ..< 18 {
                let obs = face.observe(target: target, t: t)
                let features = GazeFeatures.extract(from: obs)
                records.append(.frame(TraceFrame(
                    t: t,
                    features: features,
                    confidence: obs.confidence,
                    faceVisible: true
                )))
                t += 1.0 / 30
            }
            records.append(.label(TraceLabel(t: t, truth: target, weight: 1)))
        }
        return records
    }

    @Test("A trace round-trips through JSON Lines")
    func roundTrip() throws {
        let records = try Array(Self.session().prefix(40))
        let text = records.map(SessionTrace.encodeLine).joined(separator: "\n") + "\n\n"
        #expect(try SessionTrace.decode(text) == records)
        #expect(SessionTrace.encodeLine(records[0]).contains("saccade-trace/v2"))
    }

    @Test("Replay measures every stage, and learning from clicks beats the offset")
    func replay() throws {
        let records = try Self.session()
        let learned = TraceReplay().run(records)
        #expect(learned.labels == 24)
        #expect(learned.unmatched == 0)
        let stabilized = try #require(learned.stabilized.median)
        let corrected = try #require(learned.corrected.median)
        #expect(stabilized > 50, "\(stabilized)")
        #expect(corrected < stabilized / 2, "corrected \(corrected) vs stabilized \(stabilized)")

        var measureOnly = TraceReplay()
        measureOnly.learns = false
        let baseline = measureOnly.run(records)
        #expect(baseline.corrected.errors == baseline.stabilized.errors)
    }
}

enum TraceTestError: Error {
    case noCalibration
}
