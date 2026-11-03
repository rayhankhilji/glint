import Foundation

/// Self-correcting gaze (ARCHITECTURE §10.3): every time the user's true point of regard is known (a mouse click,
/// a target they clicked with their eyes), the residual between the estimate and that point is remembered. The
/// correction at any screen location is a kernel-weighted, recency-weighted average of nearby residuals, shrunk
/// toward zero when evidence is thin. It follows posture drift within a few clicks and fixes position-dependent
/// errors the global mapper can't.
public struct DriftCorrector: Sendable, Codable, Equatable {
    public struct Residual: Sendable, Codable, Equatable {
        public var at: Point
        public var offset: Point
        public var t: TimeInterval
        public var weight: Double
    }

    /// Spatial reach of one label (points).
    public var kernelRadius = 260.0
    /// Labels fade with this time constant (seconds).
    public var halfLife: TimeInterval = 900
    /// Pseudo-count pulling the correction toward zero (higher = needs more evidence).
    public var shrinkage = 0.6
    /// Largest correction ever applied (points).
    public var maxOffset = 220.0
    public private(set) var residuals: [Residual] = []
    static let capacity = 80

    public init() {}

    /// Records that the user was looking at `truth` while the uncorrected estimate was `estimate`.
    /// Implausible labels (farther apart than `maxOffset`) are ignored: the user was probably looking elsewhere.
    public mutating func learn(estimate: Point, truth: Point, at t: TimeInterval, weight: Double = 1) {
        let offset = truth - estimate
        guard offset.length <= maxOffset, weight > 0 else { return }
        residuals.append(Residual(at: estimate, offset: offset, t: t, weight: weight))
        if residuals.count > Self.capacity {
            residuals.removeFirst(residuals.count - Self.capacity)
        }
    }

    /// The offset to add to an uncorrected estimate at `p`.
    public func correction(at p: Point, now t: TimeInterval) -> Point {
        var sum = Point.zero
        var total = 0.0
        for r in residuals {
            let d = p.distance(to: r.at)
            let spatial = exp(-(d * d) / (2 * kernelRadius * kernelRadius))
            let age = max(0, t - r.t)
            let w = r.weight * spatial * pow(0.5, age / halfLife)
            sum += r.offset * w
            total += w
        }
        guard total > 0 else { return .zero }
        let c = sum * (1 / (total + shrinkage))
        return c.length > maxOffset ? c * (maxOffset / c.length) : c
    }

    public mutating func reset() {
        residuals.removeAll()
    }
}
