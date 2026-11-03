import AppKit
import SaccadeCore
import SaccadePerception
import SaccadePlatform
import SaccadeRuntime
import SaccadeServices
import SaccadeSystem
import SaccadeUI

/// The composition root (ARCHITECTURE §3): builds the object graph and wires streams and windows together.
/// Decisions live in SaccadeCore and SaccadeRuntime; this file only connects them.
@MainActor
final class AppEnvironment {
    let paths: AppPaths
    let settingsStore: SettingsStore
    let tracking: TrackingController
    let coordinator: IntentCoordinator
    let appModel: AppModel
    let settingsModel: SettingsModel
    let overlayModel = GazeOverlayModel()
    let calibrationModel = CalibrationModel()
    let onboardingModel: OnboardingModel
    let updater: Updater?
    let versionString: String
    let input = InputMonitor()
    let overlay: GazeOverlayWindowController
    let calibrationWindow: CalibrationWindowController
    let onboardingWindow: OnboardingWindowController
    var hotKey: HotKey?
    var settings: Settings
    var settingsTask: Task<Void, Never>?
    var permissionTask: Task<Void, Never>?
    var calibrationOpen = false
    var resumeOnboarding = false
    var accessibilityTrusted = AXService.isTrusted()
    var accessibilityPrompted = false

    /// Weight of a gaze click as a drift label: lower than a physical click, because the snap chose the target.
    static let gazeClickLabelWeight = 0.3

    static func makeLive() -> AppEnvironment {
        let isUITest = UserDefaults.standard.bool(forKey: "SaccadeUITestMode")
        return AppEnvironment(paths: .live(), bundle: .main, live: !isUITest)
    }

    init(paths: AppPaths, bundle: Bundle, live: Bool) {
        let launch = SaccadeSignposts.shared.begin(.appLaunch)
        self.paths = paths
        settingsStore = SettingsStore(paths: paths)
        let settings = settingsStore.load()
        self.settings = settings
        tracking = TrackingController(
            tracker: FaceTracker(),
            profiles: ProfileStore(paths: paths),
            settings: settings,
            pointsPerDegree: Self.pointsPerDegree()
        )
        let ax = AXService()
        coordinator = IntentCoordinator(
            settings: settings,
            targets: AccessibilityTargets(ax: ax),
            performer: SystemActuator(actuation: ActuationService(ax: ax)),
            system: LiveSystemState(input: input)
        )
        appModel = AppModel(status: .starting, accuracy: nil)
        settingsModel = SettingsModel(settings: settings, hotKeyDisplay: HotKey.defaultDisplay)
        onboardingModel = OnboardingModel(step: OnboardingModel.Step(resuming: settings.onboarding))
        onboardingModel.hotKeyDisplay = HotKey.defaultDisplay
        overlay = GazeOverlayWindowController(model: overlayModel)
        calibrationWindow = CalibrationWindowController(model: calibrationModel)
        onboardingWindow = OnboardingWindowController(model: onboardingModel)
        updater = live ? Updater(bundle: bundle) : nil
        versionString = Self.version(of: bundle)

        appModel.actions = makeActions()
        settingsModel.actions = makeSettingsActions()
        onboardingModel.actions = makeOnboardingActions()
        wireCalibration()
        wireIntent()
        tracking.onUpdate = { [weak self] in self?.sync() }
        observeSettings()
        if live {
            start()
        }
        sync()
        SaccadeSignposts.shared.end(.appLaunch, launch)
    }

    /// Starts the camera, input monitoring, the shortcut and permission polling; shows onboarding if unfinished.
    private func start() {
        tracking.apply(settings: settings)
        input.start()
        hotKey = HotKey { [weak self] in self?.toggleEnabled() }
        watchPermissions()
        if settings.onboarding != .completed {
            showOnboarding()
        }
    }

    // MARK: Intent

    func wireIntent() {
        tracking.onSample = { [weak self] sample in self?.coordinator.handle(sample) }
        coordinator.onOverlay = { [weak self] state in
            guard let self, overlayModel.state != state else { return }
            overlayModel.state = state
        }
        // Silent learning (F-04): every confirmed look-and-click is a free calibration label.
        coordinator.onTargetClicked = { [weak self] center in
            guard let self, settings.silentLearningEnabled else { return }
            tracking.learn(truth: center, weight: Self.gazeClickLabelWeight)
        }
        input.onPhysicalClick = { [weak self] point in
            guard let self, settings.silentLearningEnabled else { return }
            tracking.learn(truth: point)
        }
        coordinator.canAct = accessibilityTrusted
    }

    // MARK: State → UI

    func sync() {
        // Assign only on change: this runs for every camera frame and the popover shouldn't re-render 30×/s.
        var status = tracking.status
        if status.allowsActions, !accessibilityTrusted {
            status = .needsAttention(.accessibilityPermissionMissing)
        }
        if appModel.status != status {
            appModel.status = status
        }
        let accuracy = tracking.accuracyDegrees.map { AccuracyReading(medianErrorDegrees: $0) }
        if appModel.accuracy != accuracy {
            appModel.accuracy = accuracy
            settingsModel.accuracy = accuracy
            onboardingModel.accuracy = accuracy
        }
        syncCalibration()
        syncOverlay()
    }

    func syncOverlay() {
        let visible = !calibrationOpen && tracking.status.allowsActions && tracking.latest?.point != nil
        if visible {
            overlay.show()
        }
        if overlayModel.visible != visible {
            overlayModel.visible = visible
        }
    }

    func syncCalibration() {
        guard calibrationOpen, let session = tracking.calibration else { return }
        calibrationModel.faceVisible = tracking.latest?.faceVisible ?? false
        switch session.phase {
        case .intro:
            calibrationModel.phase = .intro
        case let .collecting(index):
            if let target = session.target {
                calibrationModel.phase = .target(
                    point: CGPoint(x: target.x, y: target.y),
                    progress: session.progress,
                    index: index
                )
            }
        case .finished:
            if let degrees = tracking.accuracyDegrees {
                calibrationModel.phase = .finished(AccuracyReading(medianErrorDegrees: degrees))
            }
        case .failed:
            calibrationModel.phase = .failed
        }
    }
}
