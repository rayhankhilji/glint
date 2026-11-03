import AppKit
import GlintCore
import GlintPlatform
import GlintRuntime
import GlintServices
import GlintUI

/// The composition root (ARCHITECTURE §3): builds the object graph and wires streams. No logic lives here
/// beyond translating popover actions into settings changes; decisions belong to GlintCore and GlintRuntime.
@MainActor
final class AppEnvironment {
    let paths: AppPaths
    let settingsStore: SettingsStore
    let intentCoordinator: IntentCoordinator
    let appModel: AppModel
    let updater: Updater?
    let versionString: String
    private var settingsTask: Task<Void, Never>?

    static func makeLive() -> AppEnvironment {
        let defaults = UserDefaults.standard
        let isUITest = defaults.bool(forKey: "GlintUITestMode")
        return AppEnvironment(
            paths: .live(),
            bundle: .main,
            startUpdater: !isUITest
        )
    }

    init(paths: AppPaths, bundle: Bundle, startUpdater: Bool) {
        let launch = GlintSignposts.shared.begin(.appLaunch)
        self.paths = paths
        settingsStore = SettingsStore(paths: paths)
        let settings = settingsStore.load()
        intentCoordinator = IntentCoordinator(settings: settings)
        appModel = AppModel(
            status: GlintStatus.resolve(settings: settings, hasCalibration: false, now: Date()),
            accuracy: nil
        )
        updater = startUpdater ? Updater(bundle: bundle) : nil
        versionString = Self.version(of: bundle)
        appModel.actions = makeActions()
        observeSettings()
        GlintSignposts.shared.end(.appLaunch, launch)
    }

    // MARK: Popover actions

    private func makeActions() -> AppActions {
        AppActions(
            setEnabled: { [weak self] enabled in
                self?.mutateSettings {
                    $0.isEnabled = enabled
                    $0.pausedUntil = nil
                }
            },
            pause: { [weak self] duration in
                self?.mutateSettings { $0.pausedUntil = duration.pausedUntil(from: Date()) }
            },
            resume: { [weak self] in self?.mutateSettings { $0.pausedUntil = nil } },
            recalibrate: {
                // Calibration arrives in ROADMAP P2.T3–P2.T4.
                GlintLog.logger(.ui).info("recalibrate requested before calibration exists")
            },
            fixProblem: { attention in
                // Permission deep links arrive in ROADMAP P4.T1.
                GlintLog.logger(.ui).info("fix requested for \(String(describing: attention), privacy: .public)")
            },
            openSettings: { NSApplication.shared.activate() },
            quit: { NSApplication.shared.terminate(nil) }
        )
    }

    private func mutateSettings(_ change: (inout Settings) -> Void) {
        var settings = settingsStore.load()
        change(&settings)
        do {
            try settingsStore.save(settings)
        } catch {
            GlintLog.log(error, in: .storage)
        }
    }

    /// Keeps the popover status and the coordinator in sync with saved settings.
    private func observeSettings() {
        let stream = settingsStore.changes()
        settingsTask = Task { [weak self] in
            for await settings in stream {
                guard let self else { return }
                appModel.status = GlintStatus.resolve(settings: settings, hasCalibration: false, now: Date())
                await intentCoordinator.update(settings: settings)
            }
        }
    }

    private static func version(of bundle: Bundle) -> String {
        let short = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(short) (\(build))"
    }
}
