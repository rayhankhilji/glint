import AppKit
import SaccadeCore
import SwiftUI

/// What the calibration screen shows (DESIGN_SYSTEM §9.3).
@MainActor
@Observable
public final class CalibrationModel {
    public enum Phase: Equatable {
        case intro
        case target(point: CGPoint, progress: Double, index: Int)
        case finished(AccuracyReading)
        case failed
    }

    public var phase: Phase = .intro
    public var faceVisible = true
    @ObservationIgnored public var onDone: @MainActor () -> Void = {}
    @ObservationIgnored public var onRetry: @MainActor () -> Void = {}
    @ObservationIgnored public var onCancel: @MainActor () -> Void = {}

    public init() {}
}

/// Full-screen calibration: a dot visits thirteen points while its ring tightens, then the accuracy result.
public struct CalibrationView: View {
    @Bindable private var model: CalibrationModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: CalibrationModel) {
        self.model = model
    }

    public var body: some View {
        ZStack {
            SaccadeColor.background.ignoresSafeArea()
            switch model.phase {
            case .intro:
                prompt(
                    String(localized: "Look at the dot and follow it"),
                    String(localized: "Sit as you normally do. Calibration takes about 20 seconds. Esc to cancel.")
                )
            case let .target(point, progress, index):
                target(progress: progress)
                    .position(point)
                    .animation(
                        reduceMotion ? .easeOut(duration: SaccadeMotion.reducedMax) : SaccadeMotion.springCalibration,
                        value: point
                    )
                    .accessibilityLabel(Text("Calibration point \(index + 1) of \(CalibrationSession.anchors.count)"))
                VStack {
                    Text(model
                        .faceVisible ? String(localized: "Follow the dot") :
                        String(localized: "Look back at the screen"))
                        .saccadeText(.bodyEmphasis)
                        .foregroundStyle(model.faceVisible ? SaccadeColor.textMuted : SaccadeColor.warning)
                        .padding(.top, SaccadeSpacing.x3l)
                    Spacer()
                }
            case let .finished(reading):
                result(reading)
            case .failed:
                failed
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private func target(progress: Double) -> some View {
        ZStack {
            Circle()
                .strokeBorder(Color.white.opacity(0.9), lineWidth: 1.25)
                .frame(width: 40 - 28 * progress, height: 40 - 28 * progress)
            Circle().fill(Color.white).frame(width: 9, height: 9)
        }
        .frame(width: 44, height: 44)
    }

    private func prompt(_ title: String, _ message: String) -> some View {
        VStack(spacing: SaccadeSpacing.s) {
            SaccadeMark(size: 40, motion: .doubleBlink)
                .padding(.bottom, SaccadeSpacing.s)
            Text(title).saccadeText(.title2).foregroundStyle(SaccadeColor.text)
            Text(message).saccadeText(.body).foregroundStyle(SaccadeColor.textMuted)
        }
    }

    private func result(_ reading: AccuracyReading) -> some View {
        VStack(spacing: SaccadeSpacing.l) {
            SaccadeMark(size: 40, motion: .still)
            VStack(spacing: SaccadeSpacing.xs) {
                Text("Calibrated").saccadeText(.title2).foregroundStyle(SaccadeColor.text)
                AccuracyReadout(reading: reading)
            }
            Text(reading.level.recommendsRetry
                ? String(localized: "Accuracy is low. More light in front of you usually helps.")
                : String(localized: "Look at any button: it locks on. Blink twice to click it."))
                .saccadeText(.callout)
                .foregroundStyle(SaccadeColor.textMuted)
            HStack(spacing: SaccadeSpacing.s) {
                Button(String(localized: "Calibrate again")) { model.onRetry() }
                    .buttonStyle(SaccadeButtonStyle(.secondary))
                Button(String(localized: "Done")) { model.onDone() }
                    .buttonStyle(SaccadeButtonStyle(.primary))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(SaccadeSpacing.xl)
        .frame(width: 400)
        .background(SaccadeColor.surface, in: RoundedRectangle(cornerRadius: SaccadeRadius.l, style: .continuous))
    }

    private var failed: some View {
        VStack(spacing: SaccadeSpacing.l) {
            VStack(spacing: SaccadeSpacing.xs) {
                Text("Couldn't see your eyes clearly").saccadeText(.title2).foregroundStyle(SaccadeColor.text)
                Text("Add light in front of you, face the screen, and try again.")
                    .saccadeText(.callout).foregroundStyle(SaccadeColor.textMuted)
            }
            HStack(spacing: SaccadeSpacing.s) {
                Button(String(localized: "Cancel")) { model.onCancel() }
                    .buttonStyle(SaccadeButtonStyle(.secondary))
                Button(String(localized: "Try again")) { model.onRetry() }
                    .buttonStyle(SaccadeButtonStyle(.primary))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(SaccadeSpacing.xl)
        .frame(width: 400)
        .background(SaccadeColor.surface, in: RoundedRectangle(cornerRadius: SaccadeRadius.l, style: .continuous))
    }
}

/// Full-screen key window on the primary display (the gaze coordinate origin); Esc cancels.
@MainActor
public final class CalibrationWindowController {
    private let window: CalibrationWindow
    private let model: CalibrationModel

    public init(model: CalibrationModel) {
        self.model = model
        let frame = GazeOverlayWindowController.primaryFrame
        window = CalibrationWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .screenSaver
        window.isOpaque = true
        window.backgroundColor = .black
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: CalibrationView(model: model))
        window.onCancel = { [weak model] in model?.onCancel() }
    }

    /// Calibration targets are laid out in this size (primary display, points).
    public var screenSize: CGSize { window.frame.size }

    public func show() {
        window.setFrame(GazeOverlayWindowController.primaryFrame, display: true)
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
    }

    public func close() {
        window.orderOut(nil)
    }
}

final class CalibrationWindow: NSWindow {
    var onCancel: @MainActor () -> Void = {}

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }
}
