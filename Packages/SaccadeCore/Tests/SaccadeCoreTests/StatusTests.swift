import Foundation
import Testing
@testable import SaccadeCore

@Suite("Status and accuracy")
struct StatusTests {
    @Test("Accuracy buckets follow PRD F-03 boundaries", arguments: [
        (0.0, AccuracyLevel.excellent), (1.5, .excellent), (1.51, .good), (2.5, .good),
        (2.51, .fair), (3.5, .fair), (3.51, .poor), (12, .poor), (-1, .poor), (.nan, .poor),
    ])
    func accuracyBuckets(error: Double, expected: AccuracyLevel) {
        #expect(AccuracyLevel(medianErrorDegrees: error) == expected)
    }

    @Test("Only poor recommends a retry")
    func retry() {
        #expect(AccuracyLevel.allCases.filter(\.recommendsRetry) == [.poor])
    }

    @Test("Glyph mapping covers DESIGN_SYSTEM §7")
    func glyphs() {
        #expect(SaccadeStatus.tracking(fps: 30).glyph == .tracking)
        #expect(SaccadeStatus.starting.glyph == .tracking)
        #expect(SaccadeStatus.paused(until: nil).glyph == .paused)
        #expect(SaccadeStatus.off.glyph == .off)
        #expect(SaccadeStatus.away.glyph == .away)
        #expect(SaccadeStatus.needsAttention(.lowLight).glyph == .away)
        for attention in SaccadeStatus.Attention.allCases where attention != .lowLight {
            #expect(SaccadeStatus.needsAttention(attention).glyph == .needsAttention)
        }
    }

    @Test("Only tracking allows actions (G-ML-01)")
    func actionsFailSafe() {
        let all: [SaccadeStatus] = [.starting, .off, .paused(until: nil), .away]
            + SaccadeStatus.Attention.allCases.map { .needsAttention($0) }
        #expect(all.allSatisfy { !$0.allowsActions })
        #expect(SaccadeStatus.tracking(fps: 30).allowsActions)
    }

    @Test("Off and missing-camera states don't use the camera (G-SEC-10)")
    func cameraUse() {
        #expect(!SaccadeStatus.off.usesCamera)
        #expect(!SaccadeStatus.needsAttention(.cameraPermissionMissing).usesCamera)
        #expect(!SaccadeStatus.needsAttention(.cameraMissing).usesCamera)
        #expect(SaccadeStatus.paused(until: nil).usesCamera)
        #expect(SaccadeStatus.away.usesCamera)
    }
}

@Suite("Pause durations")
struct PauseDurationTests {
    @Test("T-F10-AC6 (core) timed pauses end 15 min / 1 h later; until-resumed has no end")
    func endDates() {
        let start = Date(timeIntervalSince1970: 1000)
        #expect(PauseDuration.fifteenMinutes.endDate(from: start) == Date(timeIntervalSince1970: 1900))
        #expect(PauseDuration.oneHour.endDate(from: start) == Date(timeIntervalSince1970: 4600))
        #expect(PauseDuration.untilResumed.endDate(from: start) == nil)
    }
}

@Suite("Status resolution")
struct StatusResolutionTests {
    let now = Date(timeIntervalSince1970: 10000)

    private func settings(enabled: Bool = true, pausedUntil: Date? = nil) -> Settings {
        var s = Settings.defaults(installID: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7)))
        s.isEnabled = enabled
        s.pausedUntil = pausedUntil
        return s
    }

    @Test("Disabled wins over everything")
    func off() {
        #expect(SaccadeStatus.resolve(settings: settings(enabled: false), hasCalibration: true, now: now) == .off)
    }

    @Test("A future pausedUntil means paused; a past one is ignored (F-10.AC6)")
    func paused() {
        let future = now.addingTimeInterval(60)
        #expect(SaccadeStatus.resolve(settings: settings(pausedUntil: future), hasCalibration: true, now: now)
            == .paused(until: future))
        #expect(SaccadeStatus
            .resolve(settings: settings(pausedUntil: now), hasCalibration: true, now: now) == .starting)
    }

    @Test("Until-I-resume pauses are stored as distantFuture and shown without an end time")
    func untilResumed() {
        let stored = PauseDuration.untilResumed.pausedUntil(from: now)
        #expect(stored == .distantFuture)
        #expect(SaccadeStatus.resolve(settings: settings(pausedUntil: stored), hasCalibration: true, now: now)
            == .paused(until: nil))
    }

    @Test("Without calibration Saccade asks to calibrate")
    func notCalibrated() {
        #expect(SaccadeStatus.resolve(settings: settings(), hasCalibration: false, now: now)
            == .needsAttention(.notCalibrated))
    }
}
