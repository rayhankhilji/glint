import AppKit
import SaccadeCore

/// Menu bar template glyphs (DESIGN_SYSTEM §7), drawn from `Design/MenuBar/menubar-<state>.svg`.
/// The eye is constant; the state lives in the saccade's slot (sparkle, pause bars, "!" or nothing).
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
        case .tracking: String(localized: "Saccade is on")
        case .paused: String(localized: "Saccade is paused")
        case .off: String(localized: "Saccade is off")
        case .away: String(localized: "Saccade is waiting for you")
        case .needsAttention: String(localized: "Saccade needs attention")
        }
    }
}
