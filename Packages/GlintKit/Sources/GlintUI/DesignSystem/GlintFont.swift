import SwiftUI

/// Type scale (DESIGN_SYSTEM §3). Apply with `.glintText(.body)` so size, weight, tracking and line height
/// always travel together.
public enum GlintTextStyle: CaseIterable, Sendable {
    case display, title1, title2, headline, body, bodyEmphasis, callout, caption, hud, numeric, mono

    public var size: CGFloat {
        switch self {
        case .display: 34
        case .title1: 26
        case .title2: 20
        case .headline: 15
        case .body, .bodyEmphasis, .hud: 13
        case .callout: 12
        case .caption, .mono: 11
        case .numeric: 28
        }
    }

    public var lineHeight: CGFloat {
        switch self {
        case .display: 40
        case .title1, .numeric: 32
        case .title2: 26
        case .headline: 20
        case .body, .bodyEmphasis: 18
        case .callout, .hud: 16
        case .caption, .mono: 14
        }
    }

    public var weight: Font.Weight {
        switch self {
        case .display, .title1, .title2, .headline, .hud, .numeric: .semibold
        case .bodyEmphasis, .caption: .medium
        case .body, .callout, .mono: .regular
        }
    }

    public var tracking: CGFloat {
        switch self {
        case .display: -0.4
        case .title1, .numeric: -0.2
        case .title2: -0.1
        case .caption: 0.1
        default: 0
        }
    }

    public var design: Font.Design {
        switch self {
        case .numeric: .rounded
        case .mono: .monospaced
        default: .default
        }
    }

    public var font: Font {
        let font = Font.system(size: size, weight: weight, design: design)
        return self == .numeric ? font.monospacedDigit() : font
    }
}

public extension View {
    /// Applies a Glint text style: font, tracking and line spacing (DESIGN_SYSTEM §3).
    func glintText(_ style: GlintTextStyle) -> some View {
        font(style.font)
            .tracking(style.tracking)
            .lineSpacing(max(0, style.lineHeight - style.size * 1.2))
    }
}
