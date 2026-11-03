import AppKit
import SaccadeCore
import SaccadePlatform
import SaccadeRuntime
import SaccadeServices
import SaccadeSystem
import SaccadeUI
import ServiceManagement

/// Popover and Settings actions, settings persistence, and helpers.
extension AppEnvironment {
    // MARK: Popover and Settings actions

    func makeActions() -> AppActions {
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
            recalibrate: { [weak self] in self?.openCalibration() },
            fixProblem: { [weak self] attention in self?.fix(attention) },
            openSettings: { NSApplication.shared.activate() },
            quit: { NSApplication.shared.terminate(nil) }
        )
    }

    func makeSettingsActions() -> SettingsActions {
        var actions = SettingsActions(
            commit: { [weak self] settings in self?.mutateSettings { $0 = settings } },
            recalibrate: { [weak self] in self?.openCalibration() },
            deleteCalibration: { [weak self] in
                self?.tracking.deleteCalibration()
                self?.sync()
            },
            openAccessibilitySettings: { [weak self] in self?.requestAccessibility() },
            openOnboarding: { [weak self] in
                self?.onboardingModel.step = .welcome
                self?.showOnboarding()
            }
        )
        actions.revealTraces = { [weak self] in self?.revealTraces() }
        return actions
    }

    /// The global shortcut. The menu bar may be out of sight, so the HUD confirms the new state.
    func toggleEnabled() {
        mutateSettings {
            $0.isEnabled.toggle()
            $0.pausedUntil = nil
        }
        announce(settingsStore.load().isEnabled ? .turnedOn : .turnedOff)
    }

    func fix(_ attention: SaccadeStatus.Attention) {
        switch attention {
        case .cameraPermissionMissing:
            open(Self.cameraSettingsURL)
        case .accessibilityPermissionMissing:
            requestAccessibility()
        case .notCalibrated:
            openCalibration()
        case .cameraMissing, .lowLight:
            break
        }
    }

    static let cameraSettingsURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
    static let accessibilitySettingsURL =
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

    func open(_ url: String) {
        if let url = URL(string: url) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Settings

    func mutateSettings(_ change: (inout Settings) -> Void) {
        var next = settingsStore.load()
        change(&next)
        guard next != settingsStore.load() else { return }
        do {
            try settingsStore.save(next)
        } catch {
            SaccadeLog.log(error, in: .storage)
        }
    }

    func observeSettings() {
        let stream = settingsStore.changes()
        settingsTask = Task { [weak self] in
            for await settings in stream {
                guard let self else { return }
                apply(settings)
            }
        }
    }

    func apply(_ settings: Settings) {
        let previous = self.settings
        self.settings = settings
        tracking.apply(settings: settings)
        coordinator.update(settings: settings)
        if settingsModel.settings != settings {
            settingsModel.settings = settings
        }
        if settings.recordTraces != previous.recordTraces {
            updateRecording()
        }
        if settings.launchAtLogin != previous.launchAtLogin {
            applyLaunchAtLogin(settings.launchAtLogin)
        }
    }

    /// `SMAppService` is the source of truth; the setting records the user's intent.
    func applyLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled, service.status != .enabled {
                try service.register()
            } else if !enabled, service.status == .enabled {
                try service.unregister()
            }
        } catch {
            SaccadeLog.log(.persistenceFailed, in: .storage)
        }
    }

    // MARK: Helpers

    /// Points per degree of visual angle on the primary display at a typical 60 cm viewing distance, used to
    /// report calibration accuracy in degrees. Falls back to a 14" MacBook Pro value if the display size is unknown.
    static func pointsPerDegree() -> Double {
        let mm = CGDisplayScreenSize(CGMainDisplayID()).width
        let points = NSScreen.screens.first?.frame.width ?? 1512
        guard mm > 0 else { return 47 }
        let millimetersPerDegree = 2 * 600 * tan(0.5 * Double.pi / 180)
        return Double(points) / Double(mm) * millimetersPerDegree
    }

    static func version(of bundle: Bundle) -> String {
        let short = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(short) (\(build))"
    }
}
