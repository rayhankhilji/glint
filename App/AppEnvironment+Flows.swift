import AppKit
import SaccadeCore
import SaccadePerception
import SaccadeRuntime
import SaccadeSystem
import SaccadeUI

/// Calibration, onboarding and permission flows.
extension AppEnvironment {
    // MARK: Calibration

    func wireCalibration() {
        calibrationModel.onDone = { [weak self] in self?.closeCalibration() }
        calibrationModel.onCancel = { [weak self] in self?.closeCalibration() }
        calibrationModel.onRetry = { [weak self] in self?.openCalibration() }
    }

    func openCalibration() {
        calibrationOpen = true
        overlayModel.visible = false
        resumeOnboarding = onboardingWindow.isVisible
        if resumeOnboarding {
            onboardingWindow.hide()
        }
        calibrationModel.phase = .intro
        calibrationWindow.show()
        let size = calibrationWindow.screenSize
        tracking.beginCalibration(screenSize: Size(width: size.width, height: size.height))
    }

    func closeCalibration() {
        calibrationOpen = false
        calibrationWindow.close()
        tracking.endCalibration()
        if resumeOnboarding {
            showOnboarding()
        }
        resumeOnboarding = false
    }

    // MARK: Onboarding

    func showOnboarding() {
        refreshPermissions()
        onboardingWindow.show()
    }

    func makeOnboardingActions() -> OnboardingActions {
        OnboardingActions(
            requestCamera: { [weak self] in
                guard let self else { return }
                Task {
                    let granted = await self.tracking.requestCameraAccess()
                    self.onboardingModel.camera = granted ? .granted : .denied
                    if granted, self.onboardingModel.step == .camera {
                        self.onboardingModel.advance()
                    }
                }
            },
            openCameraSettings: { [weak self] in self?.open(Self.cameraSettingsURL) },
            requestAccessibility: { [weak self] in self?.requestAccessibility() },
            startCalibration: { [weak self] in self?.openCalibration() },
            stepChanged: { [weak self] step in
                self?.mutateSettings { settings in settings.onboarding = max(settings.onboarding, step.progress) }
            },
            finish: { [weak self] in
                self?.mutateSettings { $0.onboarding = .completed }
                self?.onboardingWindow.close()
            }
        )
    }

    // MARK: Permissions

    /// Accessibility can be granted at any time in System Settings and there is no notification for it, so poll
    /// cheaply (one syscall) while Saccade runs.
    func watchPermissions() {
        permissionTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refreshPermissions()
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
    }

    func refreshPermissions() {
        let trusted = AXService.isTrusted()
        if trusted != accessibilityTrusted {
            accessibilityTrusted = trusted
            coordinator.canAct = trusted
            sync()
        }
        if settingsModel.accessibilityGranted != trusted {
            settingsModel.accessibilityGranted = trusted
        }
        if onboardingModel.accessibilityGranted != trusted {
            onboardingModel.accessibilityGranted = trusted
        }
        let camera: OnboardingModel.Camera = switch tracking.cameraAuthorization {
        case .granted: .granted
        case .notDetermined: .notDetermined
        case .denied, .restricted: .denied
        }
        if onboardingModel.camera != camera {
            onboardingModel.camera = camera
        }
    }

    /// The first request shows the system prompt (which also adds Saccade to the list); later ones open the pane.
    func requestAccessibility() {
        if !accessibilityPrompted {
            accessibilityPrompted = true
            if !AXService.isTrusted(prompt: true) {
                return
            }
        }
        open(Self.accessibilitySettingsURL)
    }
}
