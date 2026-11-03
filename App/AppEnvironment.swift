import AppKit
import GlintCore
import GlintPerception
import GlintPlatform
import GlintRuntime
import GlintServices
import GlintUI

/// The composition root (ARCHITECTURE §3): builds the object graph and wires streams and windows together.
/// Decisions live in GlintCore and GlintRuntime; this file only connects them.
@MainActor
final class AppEnvironment {
    let paths: AppPaths
    let settingsStore: SettingsStore
    let tracking: TrackingController
    let appModel: AppModel
    let overlayModel = GazeOverlayModel()
    let calibrationModel = CalibrationModel()
    let updater: Updater?
    let versionString: String
    private let overlay: GazeOverlayWindowController
    private let calibrationWindow: CalibrationWindowController
    private var settingsTask: Task<Void, Never>?
    private var calibrationOpen = false

    static func makeLive() -> AppEnvironment {
        let isUITest = UserDefaults.standard.bool(forKey: "GlintUITestMode")
        return AppEnvironment(paths: .live(), bundle: .main, startUpdater: !isUITest, startTracking: !isUITest)
    }

    init(paths: AppPaths, bundle: Bundle, startUpdater: Bool, startTracking: Bool) {
        let launch = GlintSignposts.shared.begin(.appLaunch)
        self.paths = paths
        settingsStore = SettingsStore(paths: paths)
        let settings = settingsStore.load()
        tracking = TrackingController(
            tracker: FaceTracker(),
            profiles: ProfileStore(paths: paths),
            settings: settings,
            pointsPerDegree: Self.pointsPerDegree()
        )
        appModel = AppModel(status: .starting, accuracy: nil)
        overlay = GazeOverlayWindowController(model: overlayModel)
        calibrationWindow = CalibrationWindowController(model: calibrationModel)
        updater = startUpdater ? Updater(bundle: bundle) : nil
        versionString = Self.version(of: bundle)

        appModel.actions = makeActions()
        wireCalibration()
        tracking.onUpdate = { [weak self] in self?.sync() }
        tracking.onGesture = { [weak self] gesture, _ in
            if gesture == .doubleBlink {
                self?.overlayModel.pulse += 1
            }
        }
        observeSettings()
        if startTracking {
            tracking.apply(settings: settings)
        }
        sync()
        GlintSignposts.shared.end(.appLaunch, launch)
    }

    // MARK: State → UI

    private func sync() {
        // Assign only on change: this runs for every camera frame and the popover shouldn't re-render 30×/s.
        if appModel.status != tracking.status {
            appModel.status = tracking.status
        }
        let accuracy = tracking.accuracyDegrees.map { AccuracyReading(medianErrorDegrees: $0) }
        if appModel.accuracy != accuracy {
            appModel.accuracy = accuracy
        }
        syncCalibration()
        syncOverlay()
    }

    private func syncOverlay() {
        guard !calibrationOpen, tracking.status.allowsActions, let sample = tracking.latest,
              let point = sample.point else {
            overlayModel.visible = false
            return
        }
        overlay.show()
        overlayModel.visible = true
        overlayModel.point = CGPoint(x: point.x, y: point.y)
        overlayModel.radius = CGFloat(min(max(sample.sigma * 0.6, 24), 90))
        overlayModel.armed = sample.armed
    }

    private func syncCalibration() {
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

    // MARK: Calibration

    private func wireCalibration() {
        calibrationModel.onDone = { [weak self] in self?.closeCalibration() }
        calibrationModel.onCancel = { [weak self] in self?.closeCalibration() }
        calibrationModel.onRetry = { [weak self] in self?.openCalibration() }
    }

    private func openCalibration() {
        calibrationOpen = true
        overlayModel.visible = false
        calibrationModel.phase = .intro
        calibrationWindow.show()
        let size = calibrationWindow.screenSize
        tracking.beginCalibration(screenSize: Size(width: size.width, height: size.height))
    }

    private func closeCalibration() {
        calibrationOpen = false
        calibrationWindow.close()
        tracking.endCalibration()
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
            recalibrate: { [weak self] in self?.openCalibration() },
            fixProblem: { [weak self] attention in self?.fix(attention) },
            openSettings: { NSApplication.shared.activate() },
            quit: { NSApplication.shared.terminate(nil) }
        )
    }

    private func fix(_ attention: GlintStatus.Attention) {
        switch attention {
        case .cameraPermissionMissing:
            open("x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")
        case .accessibilityPermissionMissing:
            open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .notCalibrated:
            openCalibration()
        case .cameraMissing, .lowLight:
            break
        }
    }

    private func open(_ url: String) {
        if let url = URL(string: url) {
            NSWorkspace.shared.open(url)
        }
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

    private func observeSettings() {
        let stream = settingsStore.changes()
        settingsTask = Task { [weak self] in
            for await settings in stream {
                guard let self else { return }
                tracking.apply(settings: settings)
            }
        }
    }

    // MARK: Helpers

    /// Points per degree of visual angle on the main display at a typical 60 cm viewing distance, used to report
    /// calibration accuracy in degrees. Falls back to a 14" MacBook Pro value if the display size is unknown.
    private static func pointsPerDegree() -> Double {
        let mm = CGDisplayScreenSize(CGMainDisplayID()).width
        let points = NSScreen.main?.frame.width ?? 1512
        guard mm > 0 else { return 47 }
        let millimetersPerDegree = 2 * 600 * tan(0.5 * Double.pi / 180)
        return Double(points) / Double(mm) * millimetersPerDegree
    }

    private static func version(of bundle: Bundle) -> String {
        let short = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(short) (\(build))"
    }
}
