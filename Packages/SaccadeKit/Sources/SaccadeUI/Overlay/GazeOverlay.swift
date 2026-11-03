import AppKit
import SaccadeCore
import SwiftUI

/// What the gaze overlay draws: the intent engine's `OverlayState`, verbatim (DESIGN_SYSTEM §6.2).
@MainActor
@Observable
public final class GazeOverlayModel {
    public var visible = false
    public var state = OverlayState()

    public init() {}
}

/// Monochrome, dual-tone marks: an ink core with a paper halo, so every mark reads on any background without
/// color, glow or blur. The lock hugs the element 3 pt outside its frame — precise, never a blob.
public struct GazeOverlayView: View {
    @Bindable private var model: GazeOverlayModel
    @State private var pressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: GazeOverlayModel) {
        self.model = model
    }

    public var body: some View {
        let state = model.state
        ZStack(alignment: .topLeading) {
            Color.clear
            if let line = state.lineMarker {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(SaccadeColor.overlayLineHighlight)
                    .place(line.cg.insetBy(dx: -4, dy: -1))
                    .transition(.opacity)
            }
            if let window = state.windowFlash {
                DualStroke(shape: RoundedRectangle(cornerRadius: 10, style: .continuous), core: 2)
                    .place(window.cg)
                    .transition(.opacity)
            }
            ForEach(Array(state.uncertain.enumerated()), id: \.offset) { _, rect in
                DualStroke(
                    shape: RoundedRectangle(cornerRadius: Self.corner(rect.cg), style: .continuous),
                    core: 1,
                    ink: SaccadeColor.overlayUncertain,
                    dash: [3, 3]
                )
                .place(rect.cg.insetBy(dx: -Self.lockGap, dy: -Self.lockGap))
            }
            if let lock = state.lock {
                lockMark(lock.cg.insetBy(dx: -Self.lockGap, dy: -Self.lockGap), armed: state.lockPhase == .armed)
            }
            if let dot = state.gazeDot, state.lock == nil {
                Circle()
                    .fill(SaccadeColor.overlayPaper)
                    .overlay(Circle().strokeBorder(SaccadeColor.overlayInk, lineWidth: 1.5))
                    .frame(width: Self.dotSize, height: Self.dotSize)
                    .position(x: dot.x, y: dot.y)
                    .animation(reduceMotion ? nil : SaccadeMotion.springFollow, value: dot)
            }
            if let scroll = state.scrollProgress {
                scrollBar(scroll.frame.cg, progress: scroll.progress, towardTop: scroll.towardTop)
            }
        }
        .opacity(model.visible ? 1 : 0)
        .animation(.easeOut(duration: SaccadeMotion.fast), value: model.visible)
        .animation(.easeOut(duration: SaccadeMotion.fast), value: state.lineMarker)
        .animation(.easeOut(duration: SaccadeMotion.fast), value: state.windowFlash)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: state.clickCount) {
            pressed = true
            withAnimation(.easeOut(duration: 0.2).delay(0.08)) { pressed = false }
        }
    }

    private func lockMark(_ frame: CGRect, armed: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Self.corner(frame), style: .continuous)
        return ZStack {
            shape.fill(pressed ? SaccadeColor.overlayPaperFlash
                : (armed ? SaccadeColor.overlayInkFillArmed : SaccadeColor.overlayInkFill))
            DualStroke(shape: shape, core: armed ? 2 : 1.5)
        }
        .scaleEffect(pressed && !reduceMotion ? 0.96 : 1)
        .place(frame)
        .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: frame)
        .animation(.easeOut(duration: SaccadeMotion.instant), value: armed)
    }

    /// A 2 pt bar along the scroll area's edge that fills as the dwell completes.
    private func scrollBar(_ frame: CGRect, progress: Double, towardTop: Bool) -> some View {
        let width = max(frame.width - 16, 0) * min(max(progress, 0), 1)
        let y = towardTop ? frame.minY + 6 : frame.maxY - 6
        return Capsule()
            .fill(SaccadeColor.overlayInk)
            .frame(width: width, height: 2)
            .background(Capsule().fill(SaccadeColor.overlayPaper).padding(-1))
            .position(x: frame.minX + 8 + width / 2, y: y)
    }

    static let lockGap: CGFloat = 3
    static let dotSize: CGFloat = 7

    /// Follow the element's own rounding: capsule-ish for small controls, gentle for large regions.
    static func corner(_ rect: CGRect) -> CGFloat {
        min(min(rect.width, rect.height) / 2, 8)
    }
}

/// A paper halo under an ink core: legible on white, black and photos alike.
private struct DualStroke<S: InsettableShape>: View {
    let shape: S
    let core: CGFloat
    var ink = SaccadeColor.overlayInk
    var dash: [CGFloat] = []

    var body: some View {
        ZStack {
            shape.stroke(SaccadeColor.overlayPaper, style: StrokeStyle(lineWidth: core + 2, dash: dash))
            shape.stroke(ink, style: StrokeStyle(lineWidth: core, dash: dash))
        }
    }
}

private extension View {
    func place(_ rect: CGRect) -> some View {
        frame(width: max(rect.width, 0), height: max(rect.height, 0)).position(x: rect.midX, y: rect.midY)
    }
}

extension Rect {
    var cg: CGRect { CGRect(x: origin.x, y: origin.y, width: size.width, height: size.height) }
}

/// A click-through, screenshot-excluded panel covering the primary display — the origin of the global
/// top-left coordinates that Accessibility and the gaze estimate use (ARCHITECTURE §7 Overlay).
@MainActor
public final class GazeOverlayWindowController {
    private let panel: NSPanel
    private let model: GazeOverlayModel

    public init(model: GazeOverlayModel) {
        self.model = model
        let frame = Self.primaryFrame
        panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.sharingType = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: GazeOverlayView(model: model))
        panel.setAccessibilityElement(false)
    }

    /// The primary display's frame (the screen holding the menu bar at launch).
    public static var primaryFrame: NSRect {
        NSScreen.screens.first?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }

    /// The overlay's size in points: gaze coordinates are relative to this (primary display, top-left origin).
    public var screenSize: CGSize { panel.frame.size }

    public func show() {
        if panel.frame != Self.primaryFrame {
            panel.setFrame(Self.primaryFrame, display: false)
        }
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    public func hide() {
        model.visible = false
        panel.orderOut(nil)
    }
}
