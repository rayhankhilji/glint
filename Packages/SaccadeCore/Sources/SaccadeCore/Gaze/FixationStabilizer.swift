import Foundation

/// Turns noisy per-frame gaze into a steady estimate (ARCHITECTURE §10.4). While the eyes rest on something (a
/// fixation, detected by dispersion), the output converges on the robust mean of every frame in that fixation, so
/// jitter shrinks with √n instead of being merely low-passed. A saccade (a jump) is recognized after two consecutive
/// frames far from the fixation, and the output follows it at once.
public struct FixationStabilizer: Sendable {
    /// Frames farther than this from the fixation mean start a saccade (points). Scaled up with uncertainty.
    public var baseRadius: Double
    /// Longest history kept per fixation (seconds): long fixations keep adapting to slow drift.
    public var window: TimeInterval = 1.2
    private var points: [(t: TimeInterval, p: Point)] = []
    private var outliers = 0
    private var fixationStart: TimeInterval?

    public init(baseRadius: Double = 55) {
        self.baseRadius = baseRadius
    }

    /// Whether the eyes are currently in a fixation (≥ 100 ms of stable gaze).
    public func isFixating(at t: TimeInterval) -> Bool {
        guard let start = fixationStart else { return false }
        return t - start >= 0.1
    }

    /// When the current fixation began.
    public var currentFixationStart: TimeInterval? { fixationStart }

    public mutating func reset() {
        points.removeAll()
        outliers = 0
        fixationStart = nil
    }

    /// Feeds one raw estimate; returns the stabilized point.
    public mutating func ingest(_ p: Point, sigma: Double, at t: TimeInterval) -> Point {
        let radius = max(baseRadius, sigma * 1.2)
        guard let center = robustCenter() else {
            points = [(t, p)]
            fixationStart = t
            return p
        }
        if p.distance(to: center) > radius {
            outliers += 1
            if outliers >= 2 {
                // A saccade: restart the fixation at the new location.
                points = [(t, p)]
                outliers = 0
                fixationStart = t
                return p
            }
            return center
        }
        outliers = 0
        points.append((t, p))
        points.removeAll { t - $0.t > window }
        return robustCenter() ?? p
    }

    /// Mean of the points after discarding the farthest quarter (resists blink-edge glitches).
    private func robustCenter() -> Point? {
        guard !points.isEmpty else { return nil }
        let n = Double(points.count)
        let mean = Point(x: points.map(\.p.x).reduce(0, +) / n, y: points.map(\.p.y).reduce(0, +) / n)
        guard points.count >= 4 else { return mean }
        let kept = points.map(\.p).sorted { $0.distance(to: mean) < $1.distance(to: mean) }.prefix(Int(n * 0.75))
        let k = Double(kept.count)
        return Point(x: kept.map(\.x).reduce(0, +) / k, y: kept.map(\.y).reduce(0, +) / k)
    }
}
