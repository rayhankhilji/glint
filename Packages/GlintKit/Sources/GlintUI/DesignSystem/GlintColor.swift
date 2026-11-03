import SwiftUI

/// Semantic color tokens (DESIGN_SYSTEM §2). Components use these only; raw values live here and in the
/// asset catalog (`Resources/Colors.xcassets`, verified by `scripts/contrast.py`).
public enum GlintColor {
    // MARK: Chrome tokens (light/dark from the asset catalog, DESIGN_SYSTEM §2.2)

    public static var background: Color { named("background") }
    public static var surfaceTint: Color { named("surfaceTint") }
    public static var surfaceRaised: Color { named("surfaceRaised") }
    public static var border: Color { named("border") }
    public static var text: Color { named("text") }
    public static var textMuted: Color { named("textMuted") }
    public static var accent: Color { named("accent") }
    public static var onAccent: Color { named("onAccent") }
    public static var accentText: Color { named("accentText") }
    public static var success: Color { named("success") }
    public static var warning: Color { named("warning") }
    public static var danger: Color { named("danger") }
    public static var info: Color { named("info") }
    public static var focusRing: Color { named("focusRing") }
    public static var overlayScrim: Color { named("overlayScrim") }
    /// The brand glint in chrome (the mark's sparkle). The only warm color in Glint's own windows.
    public static var glintMark: Color { named("glintMark") }

    // MARK: Light tokens (overlay; appearance-independent, DESIGN_SYSTEM §2.1). Solid colors only: Glint draws

    // light as crisp geometry, never as gradients or blur.

    public static var glintCore: Color { hex(0xFFD98A) }
    public static var glintEdge: Color { hex(0x6B4300, opacity: 0.55) }
    public static var glintArmed: Color { hex(0xFFE7B3) }
    public static var glintFlare: Color { hex(0xFFF6E0) }
    public static var glintUncertain: Color { hex(0xFFD98A, opacity: 0.45) }
    /// No-AX gaze aura: a dashed ring, never a filled glow.
    public static var glintAura: Color { hex(0xFFD98A, opacity: 0.70) }
    /// Scroll-zone dwell progress line (2 pt) along the zone's edge.
    public static var glintProgress: Color { hex(0xFFD98A) }
    public static var glintWindowFlash: Color { hex(0xFFD98A, opacity: 0.70) }
    public static var glintHighContrastCore: Color { hex(0xFFB800) }
    public static var glintHighContrastEdge: Color { hex(0x000000) }
    public static var glintHighContrastInner: Color { hex(0xFFFFFF) }
    public static var debugDot: Color { hex(0xFF3B6B, opacity: 0.80) }
    /// Solid edge hairline used by `GlassSurface` on macOS 14–15 (no gradient).
    public static var glassEdge: Color { hex(0xFFFFFF, opacity: 0.22) }

    /// A chrome token by asset-catalog name (for swatches and tests; features use the named properties).
    public static func chrome(_ name: String) -> Color {
        named(name)
    }

    /// The bundle holding GlintUI's resources (colors, strings).
    public static var resourceBundle: Bundle { .module }

    private static func named(_ name: String) -> Color {
        Color(name, bundle: .module)
    }

    private static func hex(_ value: UInt32, opacity: Double = 1) -> Color {
        Color(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// Names of every chrome token, for swatch snapshots and asset-catalog drift tests.
    public static let chromeTokenNames = [
        "background", "surfaceTint", "surfaceRaised", "border", "text", "textMuted", "accent", "onAccent",
        "accentText", "success", "warning", "danger", "info", "focusRing", "glintMark", "overlayScrim",
    ]
}
