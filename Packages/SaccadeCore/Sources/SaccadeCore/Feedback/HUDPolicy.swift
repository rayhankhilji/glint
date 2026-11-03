import Foundation

/// Things worth a brief on-screen message (DESIGN_SYSTEM §9.7). The UI owns the words; this owns *whether* to speak.
public enum HUDEvent: String, Sendable, Equatable, CaseIterable {
    /// Turned on or off with the global shortcut (the menu bar isn't in view, so confirm it).
    case turnedOn, turnedOff
    /// Live accuracy has drifted well past the calibration result.
    case accuracyDipped
    /// Live accuracy has become clearly better than the calibration result thanks to clicks.
    case accuracyImproved
}

/// Rate-limits HUD messages so Saccade stays quiet: confirmations always show, advice at most once per cooldown.
public struct HUDPolicy: Sendable {
    /// Minimum time between two messages of the same advisory kind (seconds).
    public static let adviceCooldown: TimeInterval = 600
    private var lastShown: [HUDEvent: TimeInterval] = [:]

    public init() {}

    /// Whether `event` should be shown now; records it if so.
    public mutating func admit(_ event: HUDEvent, at t: TimeInterval) -> Bool {
        switch event {
        case .turnedOn, .turnedOff:
            lastShown[event] = t
            return true
        case .accuracyDipped, .accuracyImproved:
            if let last = lastShown[event], t - last < Self.adviceCooldown {
                return false
            }
            lastShown[event] = t
            return true
        }
    }
}

/// Compares live accuracy (from click labels) with the calibration result.
public enum AccuracyAdvice: Sendable, Equatable {
    case none, recalibrate, improved

    /// Worse than this many degrees *and* well past calibration → suggest recalibrating.
    static let dipFloorDegrees = AccuracyLevel.goodMaxDegrees
    static let dipRatio = 1.8
    /// At least this much better than calibration (and good in absolute terms) → say so, once.
    static let improvementDegrees = 0.5

    public static func evaluate(calibrated: Double?, live: Double?) -> AccuracyAdvice {
        guard let calibrated, let live, calibrated.isFinite, live.isFinite else { return .none }
        if live > dipFloorDegrees, live > calibrated * dipRatio {
            return .recalibrate
        }
        if live <= AccuracyLevel.excellentMaxDegrees, calibrated - live >= improvementDegrees {
            return .improved
        }
        return .none
    }
}
