import AppKit
import SaccadeCore
import SwiftUI

/// One short message (DESIGN_SYSTEM §9.7): six words or fewer, an optional symbol or the mark.
public struct HUDMessage: Hashable, Sendable {
    public var text: String
    public var symbol: SaccadeSymbol?
    public var showsMark: Bool

    public init(text: String, symbol: SaccadeSymbol? = nil, showsMark: Bool = false) {
        self.text = text
        self.symbol = symbol
        self.showsMark = showsMark
    }

    /// The words for each HUD event.
    public static func make(for event: HUDEvent, liveDegrees: Double?) -> HUDMessage {
        switch event {
        case .turnedOn:
            HUDMessage(text: String(localized: "Saccade on"), showsMark: true)
        case .turnedOff:
            HUDMessage(text: String(localized: "Saccade off"), symbol: .off)
        case .accuracyDipped:
            HUDMessage(text: String(localized: "Accuracy dipped · Recalibrate from the menu bar"), symbol: .recalibrate)
        case .accuracyImproved:
            HUDMessage(
                text: String(localized: "Accuracy now \(AccuracyReadout.degrees(liveDegrees ?? 0)) from your clicks"),
                symbol: .check
            )
        }
    }
}

/// The message currently on screen; auto-dismisses.
@MainActor
@Observable
public final class HUDModel {
    public private(set) var message: HUDMessage?
    @ObservationIgnored private var dismissal: Task<Void, Never>?
    public static let displayDuration: Duration = .milliseconds(2400)

    public init() {}

    public func show(_ message: HUDMessage) {
        self.message = message
        dismissal?.cancel()
        dismissal = Task { [weak self] in
            try? await Task.sleep(for: Self.displayDuration)
            guard !Task.isCancelled else { return }
            self?.message = nil
        }
    }
}

/// An ink capsule with paper text, top center of the primary display. Readable over anything without blur.
public struct HUDView: View {
    @Bindable private var model: HUDModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: HUDModel) {
        self.model = model
    }

    public var body: some View {
        VStack {
            if let message = model.message {
                capsule(message)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    .id(message)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(
            reduceMotion ? .easeOut(duration: SaccadeMotion.fast) : SaccadeMotion.springGentle,
            value: model.message
        )
        .allowsHitTesting(false)
    }

    private func capsule(_ message: HUDMessage) -> some View {
        HStack(spacing: SaccadeSpacing.s) {
            if message.showsMark {
                SaccadeMark(size: 14, motion: .still)
            } else if let symbol = message.symbol {
                SaccadeSymbolImage(symbol, size: 12)
            }
            Text(message.text)
                .saccadeText(.hud)
                .lineLimit(1)
        }
        .foregroundStyle(SaccadeColor.overlayPaper)
        .environment(\.colorScheme, .dark)
        .padding(.horizontal, SaccadeSpacing.l)
        .frame(height: SaccadeLayout.hudHeight)
        .background(Capsule().fill(SaccadeColor.overlayInk))
        .overlay(Capsule().strokeBorder(SaccadeColor.overlayPaper.opacity(0.16), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(message.text))
    }
}

/// A click-through panel under the menu bar on the primary display. Messages are also announced to VoiceOver.
@MainActor
public final class HUDWindowController {
    private let panel: NSPanel
    private let model: HUDModel

    public init(model: HUDModel) {
        self.model = model
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: SaccadeLayout.hudMaxWidth, height: SaccadeLayout.hudHeight + 16),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: HUDView(model: model))
    }

    public func show(_ message: HUDMessage) {
        if let screen = NSScreen.screens.first {
            let visible = screen.visibleFrame
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.maxY - size.height - 8))
        }
        panel.orderFrontRegardless()
        model.show(message)
        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: [.announcement: message.text, .priority: NSAccessibilityPriorityLevel.medium.rawValue]
        )
    }
}
