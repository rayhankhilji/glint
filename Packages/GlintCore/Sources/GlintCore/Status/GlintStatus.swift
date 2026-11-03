import Foundation

/// The app-level state shown in the menu bar and popover (PRD F-10/F-11, DESIGN_SYSTEM §9.1).
/// Produced by GlintRuntime, rendered by GlintUI.
public enum GlintStatus: Equatable, Sendable {
    /// Camera starting, ≤ 1.5 s.
    case starting
    case tracking(fps: Int)
    /// Turned off: camera stopped.
    case off
    /// Actions paused (gesture or timer). `until == nil` means until the user resumes.
    case paused(until: Date?)
    /// No face for 5 s: low-rate "away" mode.
    case away
    /// Something needs the user's attention; actions are disabled.
    case needsAttention(Attention)

    public enum Attention: Equatable, Sendable, CaseIterable {
        case cameraPermissionMissing
        case accessibilityPermissionMissing
        case cameraMissing
        case notCalibrated
        case lowLight
    }

    /// Which menu bar glyph represents this status (DESIGN_SYSTEM §7).
    public var glyph: MenuBarGlyphState {
        switch self {
        case .tracking, .starting: .tracking
        case .paused: .paused
        case .off: .off
        case .away: .away
        case let .needsAttention(attention): attention == .lowLight ? .away : .needsAttention
        }
    }

    /// Whether Glint may act (click/scroll/focus) in this status. Fail safe (G-ML-01).
    public var allowsActions: Bool {
        if case .tracking = self {
            return true
        }
        return false
    }

    /// Whether the camera should be running (G-SEC-10: off ⇒ camera stopped within 1 s).
    public var usesCamera: Bool {
        switch self {
        case .off: false
        case let .needsAttention(attention):
            attention != .cameraPermissionMissing && attention != .cameraMissing
        default: true
        }
    }
}

/// The five menu bar glyph states (DESIGN_SYSTEM §7).
public enum MenuBarGlyphState: String, Sendable, CaseIterable {
    case tracking, paused, off, away, needsAttention
}

/// Pause options offered in the popover (PRD F-10).
public enum PauseDuration: String, Sendable, CaseIterable {
    case fifteenMinutes, oneHour, untilResumed

    /// Seconds until automatic resume, or `nil` for "until I resume".
    public var seconds: TimeInterval? {
        switch self {
        case .fifteenMinutes: 15 * 60
        case .oneHour: 60 * 60
        case .untilResumed: nil
        }
    }

    /// The `pausedUntil` value for a pause starting at `now`; `nil` for "until I resume".
    public func endDate(from now: Date) -> Date? {
        seconds.map { now.addingTimeInterval($0) }
    }

    /// The value persisted in `Settings.pausedUntil`: "until I resume" is stored as `.distantFuture`.
    public func pausedUntil(from now: Date) -> Date {
        endDate(from: now) ?? .distantFuture
    }
}

public extension GlintStatus {
    /// The status implied by persisted settings alone, before perception and permissions are known.
    /// Runtime refines this (permissions, camera, face) from Phase 1 on.
    static func resolve(settings: Settings, hasCalibration: Bool, now: Date) -> GlintStatus {
        guard settings.isEnabled else { return .off }
        if let until = settings.pausedUntil, until > now {
            // `distantFuture` encodes "until I resume" (PauseDuration.untilResumed).
            return .paused(until: until == .distantFuture ? nil : until)
        }
        guard hasCalibration else { return .needsAttention(.notCalibrated) }
        return .starting
    }
}
