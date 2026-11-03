import SwiftUI

/// A quiet empty state: one custom icon, a title and one sentence (DESIGN_SYSTEM §7, §8).
public struct EmptyState: View {
    private let icon: GlintIconName
    private let title: String
    private let message: String

    public init(icon: GlintIconName, title: String, message: String) {
        self.icon = icon
        self.title = title
        self.message = message
    }

    public var body: some View {
        VStack(spacing: GlintSpacing.m) {
            GlintIcon(icon, size: 28)
                .foregroundStyle(GlintColor.textMuted)
            Text(title)
                .glintText(.headline)
                .foregroundStyle(GlintColor.text)
            Text(message)
                .glintText(.body)
                .foregroundStyle(GlintColor.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .padding(GlintSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
