import Testing
@testable import GlintCore

@Suite("Geometry")
struct GeometryTests {
    @Test("Rect edges, center and containment use top-left origin, max edges exclusive")
    func rectBasics() {
        let rect = Rect(x: 10, y: 20, width: 100, height: 40)
        #expect(rect.maxX == 110)
        #expect(rect.maxY == 60)
        #expect(rect.center == Point(x: 60, y: 40))
        #expect(rect.contains(Point(x: 10, y: 20)))
        #expect(!rect.contains(Point(x: 110, y: 40)))
        #expect(!rect.contains(Point(x: 50, y: 60)))
    }

    @Test("Distance to a rect is zero inside and edge distance outside")
    func rectDistance() {
        let rect = Rect(x: 0, y: 0, width: 10, height: 10)
        #expect(rect.distance(to: Point(x: 5, y: 5)) == 0)
        #expect(rect.distance(to: Point(x: 13, y: 14)) == 5)
        #expect(rect.nearestPoint(to: Point(x: -3, y: 4)) == Point(x: 0, y: 4))
    }

    @Test("Intersection returns the overlap or nil")
    func intersection() {
        let a = Rect(x: 0, y: 0, width: 10, height: 10)
        #expect(a.intersection(Rect(x: 5, y: 5, width: 10, height: 10)) == Rect(x: 5, y: 5, width: 5, height: 5))
        #expect(a.intersection(Rect(x: 10, y: 0, width: 5, height: 5)) == nil)
    }

    @Test("Point arithmetic and interpolation")
    func pointMath() {
        let a = Point(x: 0, y: 0)
        let b = Point(x: 3, y: 4)
        #expect(a.distance(to: b) == 5)
        #expect(a.interpolated(to: b, t: 0.5) == Point(x: 1.5, y: 2))
        #expect((b - a) * 2 == Point(x: 6, y: 8))
    }

    @Test("Inset shrinks on every side")
    func inset() {
        #expect(Rect(x: 0, y: 0, width: 10, height: 10).insetBy(dx: 2, dy: 1) == Rect(x: 2, y: 1, width: 6, height: 8))
    }

    @Test("clamped(to:) bounds values")
    func clamp() {
        #expect(5.clamped(to: 0 ... 3) == 3)
        #expect((-1.0).clamped(to: 0 ... 1) == 0)
    }
}
