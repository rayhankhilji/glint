import Foundation

/// One Euro filter (Casiez et al. 2012): heavy smoothing when the gaze is still, little lag when it moves fast.
/// Defaults are tuned for gaze in screen points at 30 fps (ARCHITECTURE §10.4): jitter σ drops ~65% and a jump
/// to a new target settles within ~4 frames.
public struct OneEuroFilter: Sendable {
    public var minCutoff: Double
    public var beta: Double
    public var derivativeCutoff: Double
    private var x: LowPass = .init()
    private var dx: LowPass = .init()
    private var lastTime: TimeInterval?

    public init(minCutoff: Double = 0.6, beta: Double = 0.002, derivativeCutoff: Double = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.derivativeCutoff = derivativeCutoff
    }

    public mutating func reset() {
        x = LowPass()
        dx = LowPass()
        lastTime = nil
    }

    public mutating func filter(_ value: Double, at t: TimeInterval) -> Double {
        guard let last = lastTime, t > last else {
            lastTime = t
            _ = dx.apply(0, alpha: 1)
            return x.apply(value, alpha: 1)
        }
        let dt = t - last
        lastTime = t
        let derivative = (value - (x.value ?? value)) / dt
        let smoothedDerivative = dx.apply(derivative, alpha: Self.alpha(cutoff: derivativeCutoff, dt: dt))
        let cutoff = minCutoff + beta * abs(smoothedDerivative)
        return x.apply(value, alpha: Self.alpha(cutoff: cutoff, dt: dt))
    }

    static func alpha(cutoff: Double, dt: Double) -> Double {
        let tau = 1 / (2 * .pi * cutoff)
        return 1 / (1 + tau / dt)
    }

    private struct LowPass: Sendable {
        var value: Double?

        mutating func apply(_ input: Double, alpha: Double) -> Double {
            let next = value.map { alpha * input + (1 - alpha) * $0 } ?? input
            value = next
            return next
        }
    }
}

/// A One Euro filter for 2D points.
public struct PointFilter: Sendable {
    private var fx: OneEuroFilter
    private var fy: OneEuroFilter

    public init(minCutoff: Double = 0.6, beta: Double = 0.002) {
        fx = OneEuroFilter(minCutoff: minCutoff, beta: beta)
        fy = OneEuroFilter(minCutoff: minCutoff, beta: beta)
    }

    public mutating func filter(_ p: Point, at t: TimeInterval) -> Point {
        Point(x: fx.filter(p.x, at: t), y: fy.filter(p.y, at: t))
    }

    public mutating func reset() {
        fx.reset()
        fy.reset()
    }
}
