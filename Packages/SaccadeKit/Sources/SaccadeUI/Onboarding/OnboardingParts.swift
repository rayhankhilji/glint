import AppKit
import SaccadeCore
import SwiftUI

// MARK: Pieces

struct StepLayout<Content: View, Actions: View>: View {
    var mark: SaccadeMark.Motion?
    let title: String
    let message: String
    @ViewBuilder let content: Content
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let mark {
                SaccadeMark(size: 36, motion: mark).padding(.bottom, SaccadeSpacing.l)
            }
            Text(title)
                .saccadeText(.title1)
                .foregroundStyle(SaccadeColor.text)
                .padding(.bottom, SaccadeSpacing.s)
            Text(message)
                .saccadeText(.body)
                .foregroundStyle(SaccadeColor.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 480, alignment: .leading)
                .padding(.bottom, SaccadeSpacing.xl)
            content
                .frame(maxWidth: 480, alignment: .leading)
            Spacer(minLength: SaccadeSpacing.l)
            HStack(spacing: SaccadeSpacing.s) {
                Spacer()
                actions
            }
        }
    }
}

struct StepIndicator: View {
    let current: OnboardingModel.Step

    var body: some View {
        HStack(spacing: SaccadeSpacing.xs) {
            ForEach(OnboardingModel.Step.allCases, id: \.self) { step in
                Capsule()
                    .fill(step.rawValue <= current.rawValue ? SaccadeColor.text : SaccadeColor.border)
                    .frame(width: step == current ? 20 : 6, height: 6)
            }
        }
        .animation(SaccadeMotion.springSnappy, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(String(localized: "Step \(current.rawValue + 1) of \(OnboardingModel.Step.allCases.count)"))
        )
    }
}

struct FeatureRow: View {
    let symbol: SaccadeSymbol
    let text: String

    var body: some View {
        HStack(spacing: SaccadeSpacing.m) {
            SaccadeSymbolImage(symbol, size: 13).foregroundStyle(SaccadeColor.text)
            Text(text).saccadeText(.body).foregroundStyle(SaccadeColor.text)
        }
    }
}

struct PermissionRow: View {
    let symbol: SaccadeSymbol
    let title: String
    let granted: Bool

    var body: some View {
        HStack(spacing: SaccadeSpacing.m) {
            SaccadeSymbolImage(symbol, size: 13).foregroundStyle(SaccadeColor.text)
            Text(title).saccadeText(.bodyEmphasis).foregroundStyle(SaccadeColor.text)
            Spacer()
            if granted {
                HStack(spacing: SaccadeSpacing.xs) {
                    SaccadeSymbolImage(.check, size: 11)
                    Text(String(localized: "Allowed")).saccadeText(.callout)
                }
                .foregroundStyle(SaccadeColor.text)
            } else {
                Text(String(localized: "Not allowed")).saccadeText(.callout).foregroundStyle(SaccadeColor.textMuted)
            }
        }
        .padding(.horizontal, SaccadeSpacing.m)
        .frame(minHeight: SaccadeLayout.formRowMinHeight)
        .background(SaccadeColor.subtle, in: RoundedRectangle(cornerRadius: SaccadeRadius.m, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct GestureRow: View {
    let gesture: String
    let result: String
    var mono = false
    var last = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(gesture)
                    .saccadeText(mono ? .mono : .body)
                    .foregroundStyle(SaccadeColor.text)
                Spacer()
                Text(result).saccadeText(.body).foregroundStyle(SaccadeColor.textMuted)
            }
            .padding(.horizontal, SaccadeSpacing.m)
            .frame(minHeight: 36)
            if !last {
                Rectangle().fill(SaccadeColor.border).frame(height: SaccadeLayout.hairline)
                    .padding(.leading, SaccadeSpacing.m)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct LabeledRow<Value: View>: View {
    let label: String
    @ViewBuilder let value: Value

    init(_ label: String, @ViewBuilder value: () -> Value) {
        self.label = label
        self.value = value()
    }

    var body: some View {
        HStack {
            Text(label).saccadeText(.body).foregroundStyle(SaccadeColor.textMuted)
            Spacer()
            value
        }
    }
}

/// A standard titled window with a transparent title bar, centered on the primary display.
@MainActor
public final class OnboardingWindowController {
    private let window: NSWindow

    public init(model: OnboardingModel) {
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: SaccadeLayout.onboardingSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.title = "Saccade"
        window.contentView = NSHostingView(rootView: OnboardingView(model: model))
    }

    public var isVisible: Bool { window.isVisible }

    public func show() {
        if !window.isVisible {
            window.center()
        }
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
    }

    /// Steps aside while the full-screen calibration runs, and comes back after.
    public func hide() {
        window.orderOut(nil)
    }

    public func close() {
        window.close()
    }
}
