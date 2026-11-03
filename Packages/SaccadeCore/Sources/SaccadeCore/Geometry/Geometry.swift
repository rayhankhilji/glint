import Foundation

// Saccade's own geometry types (ADR-004): SaccadeCore must not depend on CoreGraphics, so these replace
// CGPoint/CGSize/CGRect. All values are global display points with a top-left origin (ARCHITECTURE §4).

/// A point in global display points, top-left origin.
public struct Point: Hashable, Sendable, Codable {
    public var x: Double
    public var y: Double

    public static let zero = Point(x: 0, y: 0)

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    /// Euclidean distance to another point.
    public func distance(to other: Point) -> Double {
        (self - other).length
    }

    /// Length of the vector from the origin to this point.
    public var length: Double {
        (x * x + y * y).squareRoot()
    }

    public static func + (lhs: Point, rhs: Point) -> Point {
        Point(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    public static func - (lhs: Point, rhs: Point) -> Point {
        Point(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    public static func += (lhs: inout Point, rhs: Point) {
        lhs = lhs + rhs
    }

    public static func * (lhs: Point, rhs: Double) -> Point {
        Point(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    /// Linear interpolation: `t = 0` returns `self`, `t = 1` returns `other`.
    public func interpolated(to other: Point, t: Double) -> Point {
        self + (other - self) * t
    }
}

/// A 3D point, used for normalized landmark coordinates.
public struct Point3: Hashable, Sendable, Codable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}

/// A size in points.
public struct Size: Hashable, Sendable, Codable {
    public var width: Double
    public var height: Double

    public static let zero = Size(width: 0, height: 0)

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// An axis-aligned rectangle in global display points, top-left origin (`minY` is the top edge).
public struct Rect: Hashable, Sendable, Codable {
    public var origin: Point
    public var size: Size

    public static let zero = Rect(origin: .zero, size: .zero)

    public init(origin: Point, size: Size) {
        self.origin = origin
        self.size = size
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(origin: Point(x: x, y: y), size: Size(width: width, height: height))
    }

    public var minX: Double { origin.x }
    public var minY: Double { origin.y }
    public var maxX: Double { origin.x + size.width }
    public var maxY: Double { origin.y + size.height }
    public var width: Double { size.width }
    public var height: Double { size.height }
    public var center: Point { Point(x: origin.x + size.width / 2, y: origin.y + size.height / 2) }
    public var isEmpty: Bool { size.width <= 0 || size.height <= 0 }

    /// Whether `point` lies inside the rectangle (min edges inclusive, max edges exclusive).
    public func contains(_ point: Point) -> Bool {
        point.x >= minX && point.x < maxX && point.y >= minY && point.y < maxY
    }

    /// The overlap of two rectangles, or `nil` if they don't overlap.
    public func intersection(_ other: Rect) -> Rect? {
        let x0 = max(minX, other.minX)
        let y0 = max(minY, other.minY)
        let x1 = min(maxX, other.maxX)
        let y1 = min(maxY, other.maxY)
        guard x1 > x0, y1 > y0 else { return nil }
        return Rect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }

    /// A rectangle grown by `dx`/`dy` on each side (negative values shrink it).
    public func insetBy(dx: Double, dy: Double) -> Rect {
        Rect(x: minX + dx, y: minY + dy, width: width - 2 * dx, height: height - 2 * dy)
    }

    /// The point inside the rectangle that is nearest to `point` (the point itself if inside).
    public func nearestPoint(to point: Point) -> Point {
        Point(x: min(max(point.x, minX), maxX), y: min(max(point.y, minY), maxY))
    }

    /// Distance from `point` to the nearest point of the rectangle; 0 when inside.
    public func distance(to point: Point) -> Double {
        nearestPoint(to: point).distance(to: point)
    }
}

public extension Comparable {
    /// Clamps the value to `range`.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
