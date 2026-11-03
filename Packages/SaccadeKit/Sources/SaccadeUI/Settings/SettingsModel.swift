import Foundation
import Observation
import SaccadeCore

/// Actions Settings can trigger that are not plain settings edits. The app target supplies them.
public struct SettingsActions {
    public var commit: @MainActor (Settings) -> Void
    public var recalibrate: @MainActor () -> Void
    public var deleteCalibration: @MainActor () -> Void
    public var openAccessibilitySettings: @MainActor () -> Void
    public var openOnboarding: @MainActor () -> Void
    /// Shows the recordings folder in Finder.
    public var revealTraces: @MainActor () -> Void = {}

    public init(
        commit: @escaping @MainActor (Settings) -> Void,
        recalibrate: @escaping @MainActor () -> Void,
        deleteCalibration: @escaping @MainActor () -> Void,
        openAccessibilitySettings: @escaping @MainActor () -> Void,
        openOnboarding: @escaping @MainActor () -> Void
    ) {
        self.commit = commit
        self.recalibrate = recalibrate
        self.deleteCalibration = deleteCalibration
        self.openAccessibilitySettings = openAccessibilitySettings
        self.openOnboarding = openOnboarding
    }

    public static var noop: SettingsActions {
        SettingsActions(
            commit: { _ in },
            recalibrate: {},
            deleteCalibration: {},
            openAccessibilitySettings: {},
            openOnboarding: {}
        )
    }
}

/// State behind the Settings window. Views edit `settings` directly; the root view commits every change.
@MainActor
@Observable
public final class SettingsModel {
    public var settings: Settings
    public var accuracy: AccuracyReading?
    public var accessibilityGranted: Bool
    public var hotKeyDisplay: String
    /// Accuracy measured from recent clicks, once there are enough.
    public var liveAccuracy: AccuracyReading?
    /// Live pipeline numbers for Advanced (refreshed twice a second while running).
    public var diagnostics: LiveDiagnostics?
    @ObservationIgnored public var actions: SettingsActions

    public init(
        settings: Settings,
        accuracy: AccuracyReading? = nil,
        accessibilityGranted: Bool = true,
        hotKeyDisplay: String = "⌃⌥S",
        actions: SettingsActions = .noop
    ) {
        self.settings = settings
        self.accuracy = accuracy
        self.accessibilityGranted = accessibilityGranted
        self.hotKeyDisplay = hotKeyDisplay
        self.actions = actions
    }

    // Slider-friendly views of integer and nested settings.

    public var focusDwell: Double {
        get { Double(settings.focusFollowsGaze.dwellMs) }
        set { settings.focusFollowsGaze.dwellMs = Int(newValue.rounded()) }
    }

    public var scrollDwell: Double {
        get { Double(settings.scroll.dwellMs) }
        set { settings.scroll.dwellMs = Int(newValue.rounded()) }
    }

    public var metricsOptIn: Bool {
        get { settings.metricsConsent.allowsSending }
        set {
            settings.metricsConsent = settings.metricsConsent.updated(to: newValue ? .optedIn : .optedOut, at: Date())
        }
    }

    /// Adds an "off" rule for an app chosen by the user (no-op for duplicates).
    public func addRule(bundleID: String) {
        settings.appRules = AppRule.deduplicated(settings.appRules + [AppRule(bundleID: bundleID)])
    }

    public func removeRule(bundleID: String) {
        settings.appRules.removeAll { $0.bundleID == bundleID }
    }

    public func setMode(_ mode: AppRuleMode, for bundleID: String) {
        guard let index = settings.appRules.firstIndex(where: { $0.bundleID == bundleID }) else { return }
        settings.appRules[index].mode = mode
    }

    public func restoreDefaultRules() {
        settings.appRules = AppRule.restoringDefaults(in: settings.appRules)
    }
}

/// What Settings → Advanced shows about the running pipeline. Numbers only (G-SEC-14).
public struct LiveDiagnostics: Equatable, Sendable {
    public var framesPerSecond: Int
    /// Gaze uncertainty (points).
    public var sigmaPoints: Double
    /// Face-tracking confidence, 0...1.
    public var confidence: Double
    public var learnedClicks: Int
    /// Accessibility snapshot latency (milliseconds).
    public var accessibilityP50: Double?
    public var accessibilityP95: Double?

    public init(
        framesPerSecond: Int, sigmaPoints: Double, confidence: Double, learnedClicks: Int,
        accessibilityP50: Double?, accessibilityP95: Double?
    ) {
        self.framesPerSecond = framesPerSecond
        self.sigmaPoints = sigmaPoints
        self.confidence = confidence
        self.learnedClicks = learnedClicks
        self.accessibilityP50 = accessibilityP50
        self.accessibilityP95 = accessibilityP95
    }
}
