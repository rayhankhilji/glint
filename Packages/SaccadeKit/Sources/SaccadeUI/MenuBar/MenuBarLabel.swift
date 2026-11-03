import SaccadeCore
import SwiftUI

/// The menu bar item's label: the template glyph for the current status.
public struct MenuBarLabel: View {
    private let state: MenuBarGlyphState

    public init(state: MenuBarGlyphState) {
        self.state = state
    }

    public var body: some View {
        Image(nsImage: MenuBarGlyph.image(for: state))
            .accessibilityLabel(MenuBarGlyph.accessibilityDescription(for: state))
    }
}
