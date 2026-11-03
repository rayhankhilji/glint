import AppKit
import GlintCore
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

/// Full-screen calibration: a dot visits nine points while its ring tightens, then the accuracy result.
public struct CalibrationView: View {
    @Bindable private var model: CalibrationModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: CalibrationModel) {
        self.model = model
    }

    public var body: some View {
        ZStack {
            GlintColor.background.ignoresSafeArea()
            switch model.phase {
            case .intro:
                prompt(
                    String(localized: "Look at the dot and follow it"),
                    String(localized: "Sit as you normally do. Calibration takes about 15 seconds. Esc to cancel.")
                )
            case let .target(point, progress, index):
                target(progress: progress)
                    .position(point)
                    .animation(
                        reduceMotion ? .easeOut(duration: GlintMotion.reducedMax) : GlintMotion.springCalibration,
                        value: point
                    )
                    .accessibilityLabel(Text("Calibration point \(index + 1) of 9"))
                VStack {
                    Text(model
                        .faceVisible ? String(localized: "Follow the dot") :
                        String(localized: "Look back at the screen"))
                        .glintText(.bodyEmphasis)
                        .foregroundStyle(model.faceVisible ? GlintColor.textMuted : GlintColor.warning)
                        .padding(.top, GlintSpacing.x3l)
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
        VStack(spacing: GlintSpacing.s) {
            GlintMark(size: 40, motion: .doubleBlink)
                .padding(.bottom, GlintSpacing.s)
            Text(title).glintText(.title2).foregroundStyle(GlintColor.text)
            Text(message).glintText(.body).foregroundStyle(GlintColor.textMuted)
        }
    }

    private func result(_ reading: AccuracyReading) -> some View {
        VStack(spacing: GlintSpacing.l) {
            GlintMark(size: 40, motion: .still)
            VStack(spacing: GlintSpacing.xs) {
                Text("Calibrated").glintText(.title2).foregroundStyle(GlintColor.text)
                AccuracyReadout(reading: reading)
            }
            Text(reading.level.recommendsRetry
                ? String(localized: "Accuracy is low. More light in front of you usually helps.")
                : String(localized: "Look around: the ring follows your eyes. Blink twice to see it pulse."))
                .glintText(.callout)
                .foregroundStyle(GlintColor.textMuted)
            HStack(spacing: GlintSpacing.s) {
                Button(String(localized: "Calibrate again")) { model.onRetry() }
                    .buttonStyle(GlintButtonStyle(.secondary))
                Button(String(localized: "Done")) { model.onDone() }
                    .buttonStyle(GlintButtonStyle(.primary))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(GlintSpacing.xl)
        .frame(width: 400)
        .background(GlintColor.surface, in: RoundedRectangle(cornerRadius: GlintRadius.l, style: .continuous))
    }

    private var failed: some View {
        VStack(spacing: GlintSpacing.l) {
            VStack(spacing: GlintSpacing.xs) {
                Text("Couldn't see your eyes clearly").glintText(.title2).foregroundStyle(GlintColor.text)
                Text("Add light in front of you, face the screen, and try again.")
                    .glintText(.callout).foregroundStyle(GlintColor.textMuted)
            }
            HStack(spacing: GlintSpacing.s) {
                Button(String(localized: "Cancel")) { model.onCancel() }
                    .buttonStyle(GlintButtonStyle(.secondary))
                Button(String(localized: "Try again")) { model.onRetry() }
                    .buttonStyle(GlintButtonStyle(.primary))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(GlintSpacing.xl)
        .frame(width: 400)
        .background(GlintColor.surface, in: RoundedRectangle(cornerRadius: GlintRadius.l, style: .continuous))
    }
}

/// Full-screen key window on the main display; Esc cancels.
@MainActor
public final class CalibrationWindowController {
    private let window: CalibrationWindow
    private let model: CalibrationModel

    public init(model: CalibrationModel) {
        self.model = model
        let frame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        window = CalibrationWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .screenSaver
        window.isOpaque = true
        window.backgroundColor = .black
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: CalibrationView(model: model))
        window.onCancel = { [weak model] in model?.onCancel() }
    }

    /// Calibration targets are laid out in this size (main display, points).
    public var screenSize: CGSize { window.frame.size }

    public func show() {
        window.setFrame(NSScreen.main?.frame ?? window.frame, display: true)
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
