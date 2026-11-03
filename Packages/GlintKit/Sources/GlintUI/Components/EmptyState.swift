import SwiftUI

/// Large symbol in a soft glass circle, a title and one sentence (DESIGN_SYSTEM §7, §8).
public struct EmptyState: View {
    private let symbol: String
    private let title: String
    private let message: String

    public init(symbol: String, title: String, message: String) {
        self.symbol = symbol
        self.title = title
        self.message = message
    }

    public var body: some View {
        VStack(spacing: GlintSpacing.m) {
            GlassSurface(shape: Circle()) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(GlintColor.textMuted)
                    .frame(width: 56, height: 56)
            }
            .accessibilityHidden(true)
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
