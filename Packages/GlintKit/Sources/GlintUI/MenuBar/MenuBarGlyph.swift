import AppKit
import GlintCore

/// Menu bar template glyphs (DESIGN_SYSTEM §7), drawn from `Design/MenuBar/menubar-<state>.svg`.
/// The eye is constant; the state lives in the glint's slot (sparkle, pause bars, "!" or nothing).
public enum MenuBarGlyph {
    public static let size = NSSize(width: 18, height: 18)

    public static func image(for state: MenuBarGlyphState) -> NSImage {
        state.artwork.templateImage(
            side: size.width,
            alpha: state == .off ? 0.5 : 1,
            accessibilityDescription: accessibilityDescription(for: state)
        )
    }

    public static func accessibilityDescription(for state: MenuBarGlyphState) -> String {
        switch state {
        case .tracking: String(localized: "Glint is on", bundle: .module)
        case .paused: String(localized: "Glint is paused", bundle: .module)
        case .off: String(localized: "Glint is off", bundle: .module)
        case .away: String(localized: "Glint is waiting for you", bundle: .module)
        case .needsAttention: String(localized: "Glint needs attention", bundle: .module)
        }
    }
}
