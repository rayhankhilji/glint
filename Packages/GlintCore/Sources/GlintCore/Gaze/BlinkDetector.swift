import Foundation

/// A completed eye closure.
public struct Blink: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        /// 40–350 ms: a blink (natural or deliberate).
        case blink
        /// 400–900 ms: the second half of the right-click gesture.
        case long
    }

    public var kind: Kind
    public var start: TimeInterval
    public var end: TimeInterval
    /// Peak closure 0...1 relative to the user's open-eye baseline.
    public var depth: Double
}

/// Detects closures from eye openness, relative to a rolling open-eye baseline so it adapts to each face, camera
/// angle and lighting (ARCHITECTURE §10.4).
public struct BlinkDetector: Sendable {
    /// Closure (1 − openness / baseline) at which the eyes count as closed.
    public var closedThreshold: Double
    private var baseline: Double?
    private var closedSince: TimeInterval?
    private var peak = 0.0
    private var lastOpenTime: TimeInterval?

    public init(closedThreshold: Double = 0.45) {
        self.closedThreshold = closedThreshold
    }

    /// Current open-eye baseline (outline height / width), once learned.
    public var openBaseline: Double? { baseline }

    /// Whether a closure is in progress.
    public var isClosed: Bool { closedSince != nil }

    /// Feeds one frame. `openness` is `nil` when no face was seen; an in-progress closure is then abandoned.
    public mutating func ingest(openness: Double?, at t: TimeInterval) -> (closure: Double, blink: Blink?) {
        guard let openness, openness.isFinite, openness > 0 else {
            closedSince = nil
            peak = 0
            return (0, nil)
        }
        guard let base = baseline else {
            baseline = openness
            return (0, nil)
        }
        let closure = (1 - openness / base).clamped(to: 0 ... 1)
        if closure >= closedThreshold {
            if closedSince == nil {
                closedSince = t
            }
            peak = max(peak, closure)
            return (closure, nil)
        }
        // Eyes open: learn the baseline slowly (≈ 2 s time constant), and finish any closure.
        if closure < closedThreshold / 2 {
            baseline = base + (openness - base) * 0.05
        }
        defer {
            closedSince = nil
            peak = 0
            lastOpenTime = t
        }
        guard let start = closedSince else { return (closure, nil) }
        let duration = t - start
        let kind: Blink.Kind? = switch duration {
        case 0.04 ... 0.35: .blink
        case 0.4 ... 0.9: .long
        default: nil // too short (noise) or resting eyes: never a gesture
        }
        return (closure, kind.map { Blink(kind: $0, start: start, end: t, depth: peak) })
    }
}

/// Turns blinks into gestures (PRD F-06): double blink → click, blink then long blink → right-click.
public struct BlinkGrammar: Sendable {
    public enum Gesture: Sendable, Equatable {
        case doubleBlink
        case blinkLongBlink
    }

    /// Allowed gap between the end of the first blink and the start of the second.
    public var gapRange: ClosedRange<Double> = 0.08 ... 0.6
    /// Longest whole pattern.
    public var maxPattern: Double = 1.6
    private var first: Blink?

    public init() {}

    /// Whether the first blink of a pattern has been seen (the target is "armed").
    public var isArmed: Bool { first != nil }

    public mutating func ingest(_ blink: Blink) -> Gesture? {
        guard let first else {
            if blink.kind == .blink {
                first = blink
            }
            return nil
        }
        let gap = blink.start - first.end
        guard gapRange.contains(gap), blink.end - first.start <= maxPattern else {
            self.first = blink.kind == .blink ? blink : nil
            return nil
        }
        self.first = nil
        return blink.kind == .blink ? .doubleBlink : .blinkLongBlink
    }

    /// Clears a pending first blink once its window has passed. Never while the eyes are closed: the second
    /// closure (possibly a long one) is still in progress.
    public mutating func expire(at t: TimeInterval, eyesClosed: Bool) {
        guard !eyesClosed, let first, t - first.end > gapRange.upperBound else { return }
        self.first = nil
    }
}
