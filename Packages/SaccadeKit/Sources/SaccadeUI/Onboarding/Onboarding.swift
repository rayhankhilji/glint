import AppKit
import SaccadeCore
import SwiftUI

/// Actions onboarding triggers. The app target supplies them.
public struct OnboardingActions {
    public var requestCamera: @MainActor () -> Void
    public var openCameraSettings: @MainActor () -> Void
    public var requestAccessibility: @MainActor () -> Void
    public var startCalibration: @MainActor () -> Void
    /// Persists the resume point (F-01.AC4).
    public var stepChanged: @MainActor (OnboardingModel.Step) -> Void
    public var finish: @MainActor () -> Void

    public init(
        requestCamera: @escaping @MainActor () -> Void,
        openCameraSettings: @escaping @MainActor () -> Void,
        requestAccessibility: @escaping @MainActor () -> Void,
        startCalibration: @escaping @MainActor () -> Void,
        stepChanged: @escaping @MainActor (OnboardingModel.Step) -> Void,
        finish: @escaping @MainActor () -> Void
    ) {
        self.requestCamera = requestCamera
        self.openCameraSettings = openCameraSettings
        self.requestAccessibility = requestAccessibility
        self.startCalibration = startCalibration
        self.stepChanged = stepChanged
        self.finish = finish
    }

    public static var noop: OnboardingActions {
        OnboardingActions(
            requestCamera: {},
            openCameraSettings: {},
            requestAccessibility: {},
            startCalibration: {},
            stepChanged: { _ in },
            finish: {}
        )
    }
}

/// State behind the onboarding window (DESIGN_SYSTEM §9.1).
@MainActor
@Observable
public final class OnboardingModel {
    public enum Step: Int, CaseIterable, Sendable {
        case welcome, camera, accessibility, calibrate, done

        /// The persisted resume point for this step.
        public var progress: OnboardingProgress {
            switch self {
            case .welcome: .notStarted
            case .camera: .camera
            case .accessibility: .accessibility
            case .calibrate: .calibrate
            case .done: .playground
            }
        }

        public init(resuming progress: OnboardingProgress) {
            switch progress {
            case .notStarted: self = .welcome
            case .camera: self = .camera
            case .accessibility: self = .accessibility
            case .calibrate: self = .calibrate
            case .playground, .completed: self = .done
            }
        }
    }

    public enum Camera: Sendable, Equatable {
        case notDetermined, granted, denied
    }

    public var step: Step
    public var camera: Camera = .notDetermined
    public var accessibilityGranted = false
    public var accuracy: AccuracyReading?
    public var hotKeyDisplay = "⌃⌥S"
    @ObservationIgnored public var actions: OnboardingActions

    public init(step: Step = .welcome, actions: OnboardingActions = .noop) {
        self.step = step
        self.actions = actions
    }

    public func go(to step: Step) {
        self.step = step
        actions.stepChanged(step)
    }

    public func advance() {
        go(to: Step(rawValue: step.rawValue + 1) ?? .done)
    }
}

/// Five calm steps: what Saccade does, camera, Accessibility, calibration, and the gestures to remember.
public struct OnboardingView: View {
    @Bindable private var model: OnboardingModel

    public init(model: OnboardingModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepIndicator(current: model.step)
                .padding(.bottom, SaccadeSpacing.xxl)
            Group {
                switch model.step {
                case .welcome: welcome
                case .camera: camera
                case .accessibility: accessibility
                case .calibrate: calibrate
                case .done: done
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .transition(.opacity)
        }
        .padding(.horizontal, SaccadeSpacing.x3l)
        .padding(.top, SaccadeSpacing.x3l)
        .padding(.bottom, SaccadeSpacing.xl)
        .frame(width: SaccadeLayout.onboardingSize.width, height: SaccadeLayout.onboardingSize.height)
        .background(SaccadeColor.background)
        .animation(.easeOut(duration: SaccadeMotion.base), value: model.step)
    }

    // MARK: Steps

    private var welcome: some View {
        StepLayout(
            mark: .doubleBlink,
            title: String(localized: "Control your Mac with your eyes"),
            message: String(
                localized: """
                Saccade uses your camera to see where you look, then helps you act on it. Everything \
                runs on this Mac.
                """
            )
        ) {
            VStack(alignment: .leading, spacing: SaccadeSpacing.m) {
                FeatureRow(symbol: .gestures, text: String(localized: "Look at a button and blink twice to click it"))
                FeatureRow(
                    symbol: .scrolling,
                    text: String(localized: "Rest your eyes near the bottom of a page to scroll")
                )
                FeatureRow(symbol: .apps, text: String(localized: "Look at another window to bring it forward"))
            }
        } actions: {
            primary(String(localized: "Get Started")) { model.advance() }
        }
    }

    private var camera: some View {
        StepLayout(
            title: String(localized: "Let Saccade see your eyes"),
            message: String(
                localized: """
                Each camera frame is reduced to a few eye measurements in memory and thrown away. No \
                image is ever saved or sent.
                """
            )
        ) {
            PermissionRow(
                symbol: .camera,
                title: String(localized: "Camera"),
                granted: model.camera == .granted
            )
        } actions: {
            switch model.camera {
            case .granted:
                primary(String(localized: "Continue")) { model.advance() }
            case .notDetermined:
                primary(String(localized: "Allow Camera")) { model.actions.requestCamera() }
            case .denied:
                primary(String(localized: "Open System Settings")) { model.actions.openCameraSettings() }
            }
        }
    }

    private var accessibility: some View {
        StepLayout(
            title: String(localized: "Allow Accessibility"),
            message: String(
                localized: """
                So Saccade can find the button under your gaze and click and scroll for you. It never \
                reads what you type.
                """
            )
        ) {
            VStack(alignment: .leading, spacing: SaccadeSpacing.m) {
                PermissionRow(
                    symbol: .accessibility,
                    title: String(localized: "Accessibility"),
                    granted: model.accessibilityGranted
                )
                if !model.accessibilityGranted {
                    Text(
                        String(
                            localized: """
                            In System Settings, turn on Saccade under Privacy & Security → \
                            Accessibility. This page updates by itself.
                            """
                        )
                    )
                    .saccadeText(.callout)
                    .foregroundStyle(SaccadeColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        } actions: {
            if model.accessibilityGranted {
                primary(String(localized: "Continue")) { model.advance() }
            } else {
                Button(String(localized: "Skip for Now")) { model.advance() }
                    .buttonStyle(SaccadeButtonStyle(.secondary))
                primary(String(localized: "Open System Settings")) { model.actions.requestAccessibility() }
            }
        }
    }

    private var calibrate: some View {
        StepLayout(
            title: String(localized: "Calibrate"),
            message: String(
                localized: """
                Follow a dot around the screen for about 20 seconds. Sit as you normally do, with \
                light in front of you rather than behind.
                """
            )
        ) {
            if let accuracy = model.accuracy {
                LabeledRow(String(localized: "Last result")) { AccuracyReadout(reading: accuracy) }
            }
        } actions: {
            if model.accuracy != nil {
                Button(String(localized: "Calibrate Again")) { model.actions.startCalibration() }
                    .buttonStyle(SaccadeButtonStyle(.secondary))
                primary(String(localized: "Continue")) { model.advance() }
            } else {
                primary(String(localized: "Start Calibration")) { model.actions.startCalibration() }
            }
        }
    }

    private var done: some View {
        StepLayout(
            mark: .live,
            title: String(localized: "You're set"),
            message: String(
                localized: "Saccade gets more precise the more you use it: every click you make teaches it a little."
            )
        ) {
            VStack(spacing: 0) {
                GestureRow(gesture: String(localized: "Blink twice"), result: String(localized: "Click"))
                GestureRow(gesture: String(localized: "Blink, then hold"), result: String(localized: "Right-click"))
                GestureRow(
                    gesture: String(localized: "Rest at the bottom of a page"),
                    result: String(localized: "Scroll")
                )
                GestureRow(
                    gesture: model.hotKeyDisplay,
                    result: String(localized: "Turn Saccade on or off"),
                    mono: true,
                    last: true
                )
            }
            .background(SaccadeColor.subtle, in: RoundedRectangle(cornerRadius: SaccadeRadius.m, style: .continuous))
        } actions: {
            primary(String(localized: "Done")) { model.actions.finish() }
        }
    }

    private func primary(_ title: String, action: @escaping @MainActor () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(SaccadeButtonStyle(.primary))
            .keyboardShortcut(.defaultAction)
    }
}
