import Foundation

/// User settings persisted to `settings.json` (ARCHITECTURE §4). Decoding is lenient: unknown keys are
/// ignored and missing keys take their default, so files written by older or newer builds still load.
public struct Settings: Equatable, Sendable, Codable {
    /// Current on-disk schema. Bump only together with a new `SettingsMigrator` step.
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    /// Last on/off state (F-10).
    public var isEnabled: Bool
    /// Onboarding resume point (F-01.AC4).
    public var onboarding: OnboardingProgress
    /// The user's intent; `SMAppService` is the source of truth for the actual registration.
    public var launchAtLogin: Bool
    /// `CGDisplayCreateUUIDFromDisplayID` string; `nil` = display containing the camera / main display.
    public var gazeDisplayUUID: String?
    /// `AVCaptureDevice.uniqueID`; `nil` = first built-in / front-facing camera.
    public var cameraUniqueID: String?
    public var activeProfileKey: ProfileKey?
    public var click: ClickSettings
    public var scroll: ScrollSettings
    public var focusFollowsGaze: FocusSettings
    public var readingMarkerEnabled: Bool
    public var silentLearningEnabled: Bool
    /// F-05: disables clicks in regions without Accessibility targets.
    public var preciseTargetsOnly: Bool
    public var clickSound: Bool
    public var appRules: [AppRule]
    public var metricsConsent: MetricsConsent
    /// Timed pause end (F-10.AC6); `nil` = not paused by timer.
    public var pausedUntil: Date?
    public var debugGazeDot: Bool

    public init(
        schemaVersion: Int = Settings.currentSchemaVersion,
        isEnabled: Bool = true,
        onboarding: OnboardingProgress = .notStarted,
        launchAtLogin: Bool = false,
        gazeDisplayUUID: String? = nil,
        cameraUniqueID: String? = nil,
        activeProfileKey: ProfileKey? = nil,
        click: ClickSettings = ClickSettings(),
        scroll: ScrollSettings = ScrollSettings(),
        focusFollowsGaze: FocusSettings = FocusSettings(),
        readingMarkerEnabled: Bool = true,
        silentLearningEnabled: Bool = true,
        preciseTargetsOnly: Bool = true,
        clickSound: Bool = false,
        appRules: [AppRule] = AppRule.defaults,
        metricsConsent: MetricsConsent,
        pausedUntil: Date? = nil,
        debugGazeDot: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.isEnabled = isEnabled
        self.onboarding = onboarding
        self.launchAtLogin = launchAtLogin
        self.gazeDisplayUUID = gazeDisplayUUID
        self.cameraUniqueID = cameraUniqueID
        self.activeProfileKey = activeProfileKey
        self.click = click
        self.scroll = scroll
        self.focusFollowsGaze = focusFollowsGaze
        self.readingMarkerEnabled = readingMarkerEnabled
        self.silentLearningEnabled = silentLearningEnabled
        self.preciseTargetsOnly = preciseTargetsOnly
        self.clickSound = clickSound
        self.appRules = appRules
        self.metricsConsent = metricsConsent
        self.pausedUntil = pausedUntil
        self.debugGazeDot = debugGazeDot
    }

    /// Factory defaults for a fresh install. `installID` is injectable so tests stay deterministic.
    public static func defaults(installID: UUID = UUID()) -> Settings {
        Settings(metricsConsent: MetricsConsent(installID: installID))
    }

    /// A copy with every value clamped to its documented range (ARCHITECTURE §4) and app rules cleaned up.
    /// Called on every load so a hand-edited or corrupted value can't push the engine out of spec.
    public func validated() -> Settings {
        var copy = self
        copy.schemaVersion = Settings.currentSchemaVersion
        copy.click = click.validated()
        copy.scroll = scroll.validated()
        copy.focusFollowsGaze = focusFollowsGaze.validated()
        copy.appRules = AppRule.deduplicated(appRules)
        return copy
    }

    /// The rule for `bundleID`, if any.
    public func rule(for bundleID: String) -> AppRule? {
        appRules.first { $0.bundleID == bundleID }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, isEnabled, onboarding, launchAtLogin, gazeDisplayUUID, cameraUniqueID
        case activeProfileKey, click, scroll, focusFollowsGaze, readingMarkerEnabled, silentLearningEnabled
        case preciseTargetsOnly, clickSound, appRules, metricsConsent, pausedUntil, debugGazeDot
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings.defaults(installID: UUID())
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion, default: Settings.currentSchemaVersion)
        isEnabled = try c.decode(Bool.self, forKey: .isEnabled, default: d.isEnabled)
        onboarding = try c.decode(OnboardingProgress.self, forKey: .onboarding, default: d.onboarding)
        launchAtLogin = try c.decode(Bool.self, forKey: .launchAtLogin, default: d.launchAtLogin)
        gazeDisplayUUID = try c.decodeIfPresent(String.self, forKey: .gazeDisplayUUID)
        cameraUniqueID = try c.decodeIfPresent(String.self, forKey: .cameraUniqueID)
        activeProfileKey = try c.decodeIfPresent(ProfileKey.self, forKey: .activeProfileKey)
        click = try c.decode(ClickSettings.self, forKey: .click, default: d.click)
        scroll = try c.decode(ScrollSettings.self, forKey: .scroll, default: d.scroll)
        focusFollowsGaze = try c.decode(FocusSettings.self, forKey: .focusFollowsGaze, default: d.focusFollowsGaze)
        readingMarkerEnabled = try c.decode(Bool.self, forKey: .readingMarkerEnabled, default: d.readingMarkerEnabled)
        silentLearningEnabled = try c.decode(
            Bool.self, forKey: .silentLearningEnabled, default: d.silentLearningEnabled
        )
        preciseTargetsOnly = try c.decode(Bool.self, forKey: .preciseTargetsOnly, default: d.preciseTargetsOnly)
        clickSound = try c.decode(Bool.self, forKey: .clickSound, default: d.clickSound)
        appRules = try c.decode([AppRule].self, forKey: .appRules, default: d.appRules)
        metricsConsent = try c.decode(MetricsConsent.self, forKey: .metricsConsent, default: d.metricsConsent)
        pausedUntil = try c.decodeIfPresent(Date.self, forKey: .pausedUntil)
        debugGazeDot = try c.decode(Bool.self, forKey: .debugGazeDot, default: d.debugGazeDot)
    }
}

/// Onboarding steps in order (F-01).
public enum OnboardingProgress: String, Sendable, Codable, CaseIterable, Comparable {
    case notStarted, camera, accessibility, calibrate, playground, completed

    public static func < (lhs: OnboardingProgress, rhs: OnboardingProgress) -> Bool {
        let order = OnboardingProgress.allCases
        return order.firstIndex(of: lhs) ?? 0 < order.firstIndex(of: rhs) ?? 0
    }
}

/// Double-blink click settings (F-06).
public struct ClickSettings: Equatable, Sendable, Codable {
    public static let sensitivityRange: ClosedRange<Double> = 0 ... 1

    public var enabled: Bool
    /// 0 = fewest accidental clicks, 1 = most responsive. Maps to closure threshold ±0.1 and gap window ±60 ms.
    public var sensitivity: Double
    public var rightClickEnabled: Bool

    public init(enabled: Bool = true, sensitivity: Double = 0.5, rightClickEnabled: Bool = true) {
        self.enabled = enabled
        self.sensitivity = sensitivity
        self.rightClickEnabled = rightClickEnabled
    }

    func validated() -> ClickSettings {
        var copy = self
        copy.sensitivity = sensitivity.isFinite ? sensitivity.clamped(to: Self.sensitivityRange) : 0.5
        return copy
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ClickSettings()
        enabled = try c.decode(Bool.self, forKey: .enabled, default: d.enabled)
        sensitivity = try c.decode(Double.self, forKey: .sensitivity, default: d.sensitivity)
        rightClickEnabled = try c.decode(Bool.self, forKey: .rightClickEnabled, default: d.rightClickEnabled)
    }

    private enum CodingKeys: String, CodingKey { case enabled, sensitivity, rightClickEnabled }
}

/// Zone-triggered glide scroll settings (F-07).
public struct ScrollSettings: Equatable, Sendable, Codable {
    public static let downZoneRange: ClosedRange<Double> = 0.10 ... 0.25
    public static let upZoneRange: ClosedRange<Double> = 0.05 ... 0.20
    public static let glideRange: ClosedRange<Double> = 0.25 ... 0.60
    public static let dwellMsRange: ClosedRange<Int> = 200 ... 600

    public var enabled: Bool
    public var downZoneFraction: Double
    public var upZoneFraction: Double
    public var glideFraction: Double
    public var dwellMs: Int

    public init(
        enabled: Bool = true,
        downZoneFraction: Double = 0.15,
        upZoneFraction: Double = 0.10,
        glideFraction: Double = 0.40,
        dwellMs: Int = 300
    ) {
        self.enabled = enabled
        self.downZoneFraction = downZoneFraction
        self.upZoneFraction = upZoneFraction
        self.glideFraction = glideFraction
        self.dwellMs = dwellMs
    }

    func validated() -> ScrollSettings {
        let d = ScrollSettings()
        var copy = self
        copy.downZoneFraction = Self.clamp(downZoneFraction, Self.downZoneRange, fallback: d.downZoneFraction)
        copy.upZoneFraction = Self.clamp(upZoneFraction, Self.upZoneRange, fallback: d.upZoneFraction)
        copy.glideFraction = Self.clamp(glideFraction, Self.glideRange, fallback: d.glideFraction)
        copy.dwellMs = dwellMs.clamped(to: Self.dwellMsRange)
        return copy
    }

    private static func clamp(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? value.clamped(to: range) : fallback
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ScrollSettings()
        enabled = try c.decode(Bool.self, forKey: .enabled, default: d.enabled)
        downZoneFraction = try c.decode(Double.self, forKey: .downZoneFraction, default: d.downZoneFraction)
        upZoneFraction = try c.decode(Double.self, forKey: .upZoneFraction, default: d.upZoneFraction)
        glideFraction = try c.decode(Double.self, forKey: .glideFraction, default: d.glideFraction)
        dwellMs = try c.decode(Int.self, forKey: .dwellMs, default: d.dwellMs)
    }

    private enum CodingKeys: String,
        CodingKey { case enabled, downZoneFraction, upZoneFraction, glideFraction, dwellMs }
}

/// Gaze-to-focus settings (F-08). Defaults on with a 900 ms dwell (PRD assumption A4).
public struct FocusSettings: Equatable, Sendable, Codable {
    public static let dwellMsRange: ClosedRange<Int> = 600 ... 1500

    public var enabled: Bool
    public var dwellMs: Int

    public init(enabled: Bool = true, dwellMs: Int = 900) {
        self.enabled = enabled
        self.dwellMs = dwellMs
    }

    func validated() -> FocusSettings {
        var copy = self
        copy.dwellMs = dwellMs.clamped(to: Self.dwellMsRange)
        return copy
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = FocusSettings()
        enabled = try c.decode(Bool.self, forKey: .enabled, default: d.enabled)
        dwellMs = try c.decode(Int.self, forKey: .dwellMs, default: d.dwellMs)
    }

    private enum CodingKeys: String, CodingKey { case enabled, dwellMs }
}

/// Identifies a calibration profile: one per camera × display pair (F-03).
public struct ProfileKey: Hashable, Sendable, Codable {
    public var cameraUniqueID: String
    public var displayUUID: String

    public init(cameraUniqueID: String, displayUUID: String) {
        self.cameraUniqueID = cameraUniqueID
        self.displayUUID = displayUUID
    }
}

extension KeyedDecodingContainer {
    /// Decodes `key` if present, otherwise returns `defaultValue`. A present-but-mistyped value still throws,
    /// which `SettingsMigrator` turns into `SETTINGS_CORRUPT`.
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key, default defaultValue: T) throws -> T {
        try decodeIfPresent(type, forKey: key) ?? defaultValue
    }
}
