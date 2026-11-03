import SwiftUI

/// A problem that blocks Glint, with one fix action (DESIGN_SYSTEM §8 Banner). Flat raised surface and a
/// hairline; the icon and its color carry the severity.
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
        HStack(alignment: .top, spacing: GlintSpacing.s) {
            GlintIcon(kind == .info ? .info : .warning, size: 16)
                .foregroundStyle(tint)
            Text(message)
                .glintText(.callout)
                .foregroundStyle(GlintColor.text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderless)
                    .glintText(.bodyEmphasis)
                    .foregroundStyle(GlintColor.accentText)
                    .underline()
            }
        }
        .padding(GlintSpacing.m)
        .background(GlintColor.surfaceRaised, in: RoundedRectangle(cornerRadius: GlintRadius.m, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GlintRadius.m, style: .continuous)
                .strokeBorder(GlintColor.border, lineWidth: GlintLayout.hairline)
        )
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        switch kind {
        case .info: GlintColor.info
        case .warning: GlintColor.warning
        case .danger: GlintColor.danger
        }
    }
}
