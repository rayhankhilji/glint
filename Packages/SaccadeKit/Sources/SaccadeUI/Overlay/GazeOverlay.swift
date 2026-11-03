import AppKit
import SwiftUI

/// What the gaze overlay draws (DESIGN_SYSTEM §6.2 "No-AX aura" until target snapping lands in Phase 3).
@MainActor
@Observable
public final class GazeOverlayModel {
    public var visible = false
    /// Gaze point in the overlay's coordinates (top-left origin, points).
    public var point: CGPoint = .zero
    /// Ring radius: the live uncertainty, clamped to a readable size.
    public var radius: CGFloat = 40
    /// First blink of a double blink seen.
    public var armed = false
    /// Incremented on each recognized gesture; drives the click pulse.
    public var pulse = 0

    public init() {}
}

/// An indigo ring with a soft fill that follows your gaze, brightens when armed and pulses on a double blink.
public struct GazeOverlayView: View {
    @Bindable private var model: GazeOverlayModel
    @State private var flash = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: GazeOverlayModel) {
        self.model = model
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            ring
                .frame(width: model.radius * 2, height: model.radius * 2)
                .position(model.point)
                .opacity(model.visible ? 1 : 0)
                .animation(reduceMotion ? nil : SaccadeMotion.springFollow, value: model.point)
                .animation(.easeOut(duration: SaccadeMotion.fast), value: model.visible)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: model.pulse) {
            flash = true
            withAnimation(.easeOut(duration: 0.18).delay(0.06)) { flash = false }
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .fill(flash ? SaccadeColor
                    .overlayFillPress : (model.armed ? SaccadeColor.overlayFillArmed : SaccadeColor.overlayFill))
            Circle().strokeBorder(SaccadeColor.overlayHairline, lineWidth: 1).padding(1.5)
            Circle().strokeBorder(SaccadeColor.overlayRing, lineWidth: model.armed ? 2 : 1.5)
        }
        .scaleEffect(flash && !reduceMotion ? 0.92 : 1)
        .animation(.easeOut(duration: SaccadeMotion.instant), value: model.armed)
    }
}

/// A click-through, screenshot-excluded panel covering the main display (ARCHITECTURE §7 Overlay).
@MainActor
public final class GazeOverlayWindowController {
    private let panel: NSPanel
    private let model: GazeOverlayModel

    public init(model: GazeOverlayModel) {
        self.model = model
        let frame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
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

    /// The overlay's size in points: gaze coordinates are relative to this (main display, top-left origin).
    public var screenSize: CGSize { panel.frame.size }

    public func show() {
        panel.setFrame(NSScreen.main?.frame ?? panel.frame, display: false)
        panel.orderFrontRegardless()
    }

    public func hide() {
        model.visible = false
        panel.orderOut(nil)
    }
}
