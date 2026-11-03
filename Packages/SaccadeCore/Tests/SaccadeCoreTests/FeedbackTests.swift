import Testing
@testable import SaccadeCore

@Suite("HUD policy and accuracy advice")
struct FeedbackTests {
    @Test("Shortcut confirmations always show; advice shows at most once per 10 minutes")
    func rateLimits() {
        var policy = HUDPolicy()
        let sequence: [(HUDEvent, Double, Bool)] = [
            (.turnedOff, 0, true), (.turnedOn, 1, true), (.turnedOff, 2, true),
            (.accuracyDipped, 10, true), (.accuracyDipped, 300, false),
            (.accuracyImproved, 300, true), // independent kinds
            (.accuracyDipped, 10 + HUDPolicy.adviceCooldown, true),
        ]
        for (event, t, expected) in sequence {
            let shown = policy.admit(event, at: t)
            #expect(shown == expected, "\(event) at \(t)")
        }
    }

    @Test("Recalibration is suggested only when live accuracy is both poor and far past calibration")
    func advice() {
        #expect(AccuracyAdvice.evaluate(calibrated: 1.2, live: 3.1) == .recalibrate)
        #expect(AccuracyAdvice.evaluate(calibrated: 1.2, live: 2.0) == .none) // worse, but still good
        #expect(AccuracyAdvice.evaluate(calibrated: 3.0, live: 3.4) == .none) // as calibrated
        #expect(AccuracyAdvice.evaluate(calibrated: 2.2, live: 1.3) == .improved)
        #expect(AccuracyAdvice.evaluate(calibrated: nil, live: 5) == .none)
        #expect(AccuracyAdvice.evaluate(calibrated: 2, live: nil) == .none)
    }
}
