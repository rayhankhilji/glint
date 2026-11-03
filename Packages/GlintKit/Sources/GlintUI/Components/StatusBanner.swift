import SwiftUI

/// A one-line problem banner with an optional fix action (DESIGN_SYSTEM §8 Banner).
public struct StatusBanner: View {
    public enum Kind: Sendable {
        case info, warning, danger
    }

    private let kind: Kind
    private let message: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(kind: Kind, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.kind = kind
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: GlintSpacing.s) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(message)
                .glintText(.callout)
                .foregroundStyle(GlintColor.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: GlintSpacing.s)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderless)
                    .foregroundStyle(GlintColor.accentText)
                    .glintText(.bodyEmphasis)
            }
        }
        .padding(GlintSpacing.m)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: GlintRadius.m, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }

    private var tint: Color {
        switch kind {
        case .info: GlintColor.info
        case .warning: GlintColor.warning
        case .danger: GlintColor.danger
        }
    }

    private var symbol: String {
        switch kind {
        case .info: "info.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .danger: "exclamationmark.octagon.fill"
        }
    }
}
