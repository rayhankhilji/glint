import AppKit
import GlintCore

/// Draws the menu bar template glyphs (DESIGN_SYSTEM §7): an eye with a four-point sparkle at the upper right.
/// Drawn in code so all five states share exact geometry and stay crisp at every scale.
public enum MenuBarGlyph {
    public static let size = NSSize(width: 18, height: 18)

    public static func image(for state: MenuBarGlyphState) -> NSImage {
        let image = NSImage(size: size, flipped: true) { _ in
            draw(state)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = accessibilityDescription(for: state)
        return image
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

    // Geometry in an 18 × 18 flipped (top-left origin) canvas.
    private static let eyeRect = NSRect(x: 1.5, y: 5, width: 13, height: 9)
    private static let sparkleCenter = NSPoint(x: 14.5, y: 3.5)

    private static func draw(_ state: MenuBarGlyphState) {
        let alpha: CGFloat = state == .off ? 0.5 : 1
        NSColor.black.withAlphaComponent(alpha).set()

        let eye = eyePath(halfClosed: state == .away)
        eye.lineWidth = 1.4
        eye.stroke()
        if state != .away {
            NSBezierPath(ovalIn: NSRect(x: eyeRect.midX - 2, y: eyeRect.midY - 2, width: 4, height: 4)).fill()
        }

        switch state {
        case .tracking:
            sparkle(radius: 3.5).fill()
        case .paused:
            outlined(sparkle(radius: 3.5))
            NSBezierPath(rect: NSRect(x: 13, y: 12, width: 1.3, height: 4.5)).fill()
            NSBezierPath(rect: NSRect(x: 15.5, y: 12, width: 1.3, height: 4.5)).fill()
        case .off:
            break
        case .away:
            outlined(sparkle(radius: 3.5))
        case .needsAttention:
            sparkle(radius: 3.5).fill()
            NSBezierPath(rect: NSRect(x: 15, y: 10.5, width: 1.6, height: 4)).fill()
            NSBezierPath(ovalIn: NSRect(x: 15, y: 15.5, width: 1.6, height: 1.6)).fill()
        }
    }

    private static func outlined(_ path: NSBezierPath) {
        path.lineWidth = 1
        path.stroke()
    }

    /// Almond eye: two arcs meeting at the corners. Half-closed lowers the upper lid.
    private static func eyePath(halfClosed: Bool) -> NSBezierPath {
        let left = NSPoint(x: eyeRect.minX, y: eyeRect.midY)
        let right = NSPoint(x: eyeRect.maxX, y: eyeRect.midY)
        let topControl = halfClosed ? eyeRect.midY - 1 : eyeRect.minY - 2.5
        let path = NSBezierPath()
        path.move(to: left)
        path.curve(
            to: right,
            controlPoint1: NSPoint(x: eyeRect.minX + 3, y: topControl),
            controlPoint2: NSPoint(x: eyeRect.maxX - 3, y: topControl)
        )
        path.curve(
            to: left,
            controlPoint1: NSPoint(x: eyeRect.maxX - 3, y: eyeRect.maxY + 2.5),
            controlPoint2: NSPoint(x: eyeRect.minX + 3, y: eyeRect.maxY + 2.5)
        )
        path.close()
        return path
    }

    /// Four-point star with concave sides (the "glint").
    private static func sparkle(radius r: CGFloat) -> NSBezierPath {
        let c = sparkleCenter
        let inner = r * 0.28
        let path = NSBezierPath()
        path.move(to: NSPoint(x: c.x, y: c.y - r))
        path.curve(
            to: NSPoint(x: c.x + r, y: c.y),
            controlPoint1: NSPoint(x: c.x + inner, y: c.y - inner),
            controlPoint2: NSPoint(x: c.x + inner, y: c.y - inner)
        )
        path.curve(
            to: NSPoint(x: c.x, y: c.y + r),
            controlPoint1: NSPoint(x: c.x + inner, y: c.y + inner),
            controlPoint2: NSPoint(x: c.x + inner, y: c.y + inner)
        )
        path.curve(
            to: NSPoint(x: c.x - r, y: c.y),
            controlPoint1: NSPoint(x: c.x - inner, y: c.y + inner),
            controlPoint2: NSPoint(x: c.x - inner, y: c.y + inner)
        )
        path.curve(
            to: NSPoint(x: c.x, y: c.y - r),
            controlPoint1: NSPoint(x: c.x - inner, y: c.y - inner),
            controlPoint2: NSPoint(x: c.x - inner, y: c.y - inner)
        )
        path.close()
        return path
    }
}
