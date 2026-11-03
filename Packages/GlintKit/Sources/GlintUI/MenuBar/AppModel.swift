import GlintCore
import Observation

/// Actions the popover can trigger. GlintRuntime supplies the real implementations; previews use `.noop`.
public struct AppActions {
    public var setEnabled: @MainActor (Bool) -> Void
    public var pause: @MainActor (PauseDuration) -> Void
    public var resume: @MainActor () -> Void
    public var recalibrate: @MainActor () -> Void
    public var fixProblem: @MainActor (GlintStatus.Attention) -> Void
    public var openSettings: @MainActor () -> Void
    public var quit: @MainActor () -> Void

    public init(
        setEnabled: @escaping @MainActor (Bool) -> Void,
        pause: @escaping @MainActor (PauseDuration) -> Void,
        resume: @escaping @MainActor () -> Void,
        recalibrate: @escaping @MainActor () -> Void,
        fixProblem: @escaping @MainActor (GlintStatus.Attention) -> Void,
        openSettings: @escaping @MainActor () -> Void,
        quit: @escaping @MainActor () -> Void
    ) {
        self.setEnabled = setEnabled
        self.pause = pause
        self.resume = resume
        self.recalibrate = recalibrate
        self.fixProblem = fixProblem
        self.openSettings = openSettings
        self.quit = quit
    }

    public static var noop: AppActions {
        AppActions(
            setEnabled: { _ in }, pause: { _ in }, resume: {}, recalibrate: {}, fixProblem: { _ in },
            openSettings: {}, quit: {}
        )
    }
}

/// State behind the menu bar item and popover (ARCHITECTURE §7). P0: driven by static values; GlintRuntime
/// feeds it live from Phase 2 on.
@MainActor
@Observable
public final class AppModel {
    public var status: GlintStatus
    public var accuracy: AccuracyReading?
    @ObservationIgnored public var actions: AppActions

    public init(status: GlintStatus, accuracy: AccuracyReading?, actions: AppActions = .noop) {
        self.status = status
        self.accuracy = accuracy
        self.actions = actions
    }

    /// The main switch is on unless Glint is off.
    public var isEnabled: Bool {
        status != .off
    }

    /// The switch can't turn Glint on while a permission is missing.
    public var canToggle: Bool {
        switch status {
        case .needsAttention(.cameraPermissionMissing), .needsAttention(.accessibilityPermissionMissing): false
        default: true
        }
    }

    public var glyph: MenuBarGlyphState { status.glyph }

    public func setEnabled(_ enabled: Bool) {
        actions.setEnabled(enabled)
    }
}
