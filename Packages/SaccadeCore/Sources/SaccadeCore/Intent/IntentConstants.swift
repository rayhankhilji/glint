import Foundation

/// Every intent threshold in one place (G-ML-05). Changing one needs a before/after eval and human approval.
public enum IntentConstants {
    // Snapping (F-05)
    /// Snap reach is the gaze uncertainty times this, clamped to `snapSigmaRange` (points).
    public static let snapSigmaFactor = 0.45
    public static let snapSigmaRange: ClosedRange<Double> = 14 ... 90
    /// Candidates are considered within this many snap-sigmas of the gaze.
    public static let snapReachSigmas = 3.0
    /// Score bonus exponent favoring smaller targets when the gaze is inside nested ones.
    public static let sizePriorExponent = 0.12
    /// A challenger must beat the current lock by this factor…
    public static let switchMargin = 1.3
    /// …for this long (seconds) to take over.
    public static let switchHold = 0.12
    /// The lock is dropped when its score stays below this for `dropHold` seconds.
    public static let dropScore = 0.04
    public static let dropHold = 0.18
    /// Top two candidates closer than this ratio are "uncertain": shown, never clicked.
    public static let uncertainRatio = 1.18
    public static let uncertainMinScore = 0.3
    public static let minTargetSide = 8.0

    // Clicking (F-06)
    /// The lock must have been stable this long before the first blink.
    public static let clickLockStable = 0.25
    public static let clickCooldown = 0.5
    /// Target id for a click at the gaze point with no Accessibility element (never issued by the AX registry).
    public static let freeTargetID = -1
    /// Unit conversion for millisecond settings.
    public static let millisecondsPerSecond = 1000.0

    // Scrolling (F-07)
    public static let scrollUpDwell = 0.45
    public static let scrollUpFraction = 0.3
    public static let scrollCooldown = 0.7
    public static let manualScrollSuspend = 2.0
    public static let glideDuration = 0.52

    // Focus follows gaze (F-08)
    public static let focusTypingGuard = 1.5
    public static let focusCooldown = 1.5

    // Where was I (F-09)
    public static let readingBreak = 2.0
    public static let readingReturnWindow = 600.0
    /// How long the line marker stays on screen (sweep 450 ms + hold 600 ms + fade 600 ms).
    public static let lineMarkerDuration = 1.65
    public static let lineBandHeight = 24.0
    public static let lineInset = 12.0

    /// Manual input precedence (G-ML-08)
    public static let pointerHidesOverlay = 1.2

    /// Shared
    public static let half = 0.5
}
