import GlintCore

/// Joins the perception stream, Accessibility snapshots and input activity, steps the `IntentEngine`, and
/// dispatches the resulting actions and overlay state (ARCHITECTURE §3, §6.1). It is the only place that does so.
///
/// P0 skeleton: it holds the current settings so the wiring from `SettingsStore` exists end to end.
/// The pipeline is joined in ROADMAP P3.T4.
public actor IntentCoordinator {
    public private(set) var settings: Settings

    public init(settings: Settings) {
        self.settings = settings
    }

    /// Applies new settings (called from the settings `changes` stream).
    public func update(settings: Settings) {
        self.settings = settings.validated()
    }
}
