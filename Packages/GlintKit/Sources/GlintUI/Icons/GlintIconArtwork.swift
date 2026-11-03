import AppKit
import SwiftUI

/// One drawing command in icon-grid coordinates (top-left origin). Generated from SVG by
/// `scripts/icons/build_icons.py`; arcs are already converted to cubics.
public enum GlintIconCommand: Sendable, Equatable {
    case move(CGFloat, CGFloat)
    case line(CGFloat, CGFloat)
    case curve(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)
    case quad(CGFloat, CGFloat, CGFloat, CGFloat)
    case close
}

/// A named piece of an icon (`data-part` in the SVG). Parts can be animated independently.
public struct GlintIconPart: Sendable, Equatable {
    public enum Style: Sendable { case stroke, fill }

    public let id: String
    public let style: Style
    public let commands: [GlintIconCommand]

    /// The part's path scaled from the icon grid into a square of side `side` points.
    public func path(side: CGFloat, grid: CGFloat) -> Path {
        let s = side / grid
        var path = Path()
        for command in commands {
            switch command {
            case let .move(x, y): path.move(to: CGPoint(x: x * s, y: y * s))
            case let .line(x, y): path.addLine(to: CGPoint(x: x * s, y: y * s))
            case let .curve(x1, y1, x2, y2, x, y):
                path.addCurve(
                    to: CGPoint(x: x * s, y: y * s),
                    control1: CGPoint(x: x1 * s, y: y1 * s),
                    control2: CGPoint(x: x2 * s, y: y2 * s)
                )
            case let .quad(x1, y1, x, y):
                path.addQuadCurve(to: CGPoint(x: x * s, y: y * s), control: CGPoint(x: x1 * s, y: y1 * s))
            case .close: path.closeSubpath()
            }
        }
        return path
    }

    /// Bounds in grid units (control points included), for layout tests and part-relative animation anchors.
    public var gridBounds: CGRect {
        var points: [CGPoint] = []
        for command in commands {
            switch command {
            case let .move(x, y), let .line(x, y): points.append(CGPoint(x: x, y: y))
            case let .curve(x1, y1, x2, y2, x, y): points += [
                    CGPoint(x: x1, y: y1),
                    CGPoint(x: x2, y: y2),
                    CGPoint(x: x, y: y),
                ]
            case let .quad(x1, y1, x, y): points += [CGPoint(x: x1, y: y1), CGPoint(x: x, y: y)]
            case .close: break
            }
        }
        guard let first = points.first else { return .null }
        return points.dropFirst()
            .reduce(CGRect(origin: first, size: .zero)) { $0.union(CGRect(origin: $1, size: .zero)) }
    }
}

/// A complete icon: grid size, stroke width (grid units) and parts in drawing order.
public struct GlintIconArtwork: Sendable, Equatable {
    public let grid: CGFloat
    public let strokeWidth: CGFloat
    public let parts: [GlintIconPart]

    public func part(_ id: String) -> GlintIconPart? {
        parts.first { $0.id == id }
    }

    /// Stroke style for this icon drawn at `side` points: the stroke scales with the icon, round caps and joins.
    public func strokeStyle(side: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: strokeWidth * side / grid, lineCap: .round, lineJoin: .round)
    }

    /// A template `NSImage` (menu bar, Settings tabs). Template images take the system's tint and vibrancy.
    public func templateImage(side: CGFloat, alpha: CGFloat = 1, accessibilityDescription: String) -> NSImage {
        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { _ in
            NSColor.black.withAlphaComponent(alpha).set()
            for part in parts {
                let path = NSBezierPath(cgPath: part.path(side: side, grid: grid).cgPath)
                switch part.style {
                case .fill:
                    path.fill()
                case .stroke:
                    path.lineWidth = strokeWidth * side / grid
                    path.lineCapStyle = .round
                    path.lineJoinStyle = .round
                    path.stroke()
                }
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = accessibilityDescription
        return image
    }
}
