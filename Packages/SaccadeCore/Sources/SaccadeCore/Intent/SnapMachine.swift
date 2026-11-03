import Foundation

/// Magnetic target snapping (PRD F-05): picks the element the user is most likely looking at, with hysteresis so
/// the highlight never flickers between neighbors, and an "uncertain" state when two targets are too close to call.
public struct SnapMachine: Sendable {
    public struct Lock: Sendable, Equatable {
        public var candidate: TargetCandidate
        public var since: TimeInterval
        public var score: Double
    }

    public private(set) var lock: Lock?
    public private(set) var uncertain: [TargetCandidate] = []
    private var challenger: (id: Int, since: TimeInterval)?
    private var weakSince: TimeInterval?

    public init() {}

    public mutating func reset() {
        lock = nil
        uncertain = []
        challenger = nil
        weakSince = nil
    }

    /// Likelihood that the gaze at `gaze` with spread `sigma` is on `frame` (1 inside, Gaussian falloff outside),
    /// with a mild preference for smaller (more specific) targets.
    public static func score(_ frame: Rect, gaze: Point, sigma: Double) -> Double {
        let d = frame.distance(to: gaze)
        let gaussian = exp(-(d * d) / (sigma * sigma + sigma * sigma))
        let area = max(frame.width * frame.height, IntentConstants.minTargetSide * IntentConstants.minTargetSide)
        return gaussian * pow(area, -IntentConstants.sizePriorExponent)
    }

    /// Snap reach for a given gaze uncertainty.
    public static func snapSigma(for sigma: Double) -> Double {
        (sigma * IntentConstants.snapSigmaFactor).clamped(to: IntentConstants.snapSigmaRange)
    }

    /// A candidate with its raw score and its score relative to the best one this frame.
    struct Scored {
        var candidate: TargetCandidate
        var score: Double
        var relative: Double
    }

    /// Updates the lock. `frozen` keeps the current lock (used while a double blink is in progress).
    public mutating func step(
        gaze: Point?,
        sigma: Double,
        candidates: [TargetCandidate],
        at t: TimeInterval,
        frozen: Bool
    ) {
        guard let gaze else {
            reset()
            return
        }
        if frozen, lock != nil {
            return
        }
        let scored = Self.rank(candidates, gaze: gaze, sigma: Self.snapSigma(for: sigma))
        if isTie(scored) {
            uncertain = [scored[0].candidate, scored[1].candidate]
            lock = nil
            challenger = nil
            return
        }
        uncertain = []
        guard let best = scored.first else {
            dropIfWeak(at: t)
            return
        }
        guard let current = lock else {
            lock = Lock(candidate: best.candidate, since: t, score: best.score)
            return
        }
        // Refresh the current lock's frame and score (the element may have moved).
        let currentEntry = scored.first { $0.candidate.id == current.candidate.id }
        if let entry = currentEntry {
            lock = Lock(candidate: entry.candidate, since: current.since, score: entry.score)
            weakSince = nil
        } else {
            dropIfWeak(at: t)
            if lock == nil {
                lock = Lock(candidate: best.candidate, since: t, score: best.score)
                return
            }
        }
        challenge(with: best, against: currentEntry?.score ?? 0, at: t)
    }

    /// Reachable, large-enough candidates by descending score, normalized so thresholds don't depend on units.
    static func rank(_ candidates: [TargetCandidate], gaze: Point, sigma s: Double) -> [Scored] {
        let reach = s * IntentConstants.snapReachSigmas
        let side = IntentConstants.minTargetSide
        let raw = candidates
            .filter { $0.frame.width >= side && $0.frame.height >= side && $0.frame.distance(to: gaze) <= reach }
            .map { Scored(candidate: $0, score: score($0.frame, gaze: gaze, sigma: s), relative: 0) }
            .sorted { $0.score > $1.score }
        let top = raw.first?.score ?? 0
        return raw.map { Scored(candidate: $0.candidate, score: $0.score, relative: top > 0 ? $0.score / top : 0) }
    }

    /// Two good candidates nearly tied, neither already locked: too close to call.
    private func isTie(_ scored: [Scored]) -> Bool {
        guard scored.count > 1 else { return false }
        let first = scored[0], second = scored[1]
        let unlocked = lock.map {
            $0.candidate.id != first.candidate.id && $0.candidate.id != second.candidate.id
        } ?? true
        return second.relative * IntentConstants.uncertainRatio >= 1
            && second.relative >= IntentConstants.uncertainMinScore && unlocked
    }

    /// Hysteresis: a different best candidate takes over only after beating the lock by a margin for a while.
    private mutating func challenge(with best: Scored, against currentScore: Double, at t: TimeInterval) {
        guard let current = lock, best.candidate.id != current.candidate.id,
              best.score > currentScore * IntentConstants.switchMargin
        else {
            challenger = nil
            return
        }
        guard let ch = challenger, ch.id == best.candidate.id else {
            challenger = (best.candidate.id, t)
            return
        }
        if t - ch.since >= IntentConstants.switchHold {
            lock = Lock(candidate: best.candidate, since: t, score: best.score)
            challenger = nil
        }
    }

    private mutating func dropIfWeak(at t: TimeInterval) {
        guard lock != nil else { return }
        if let since = weakSince {
            if t - since >= IntentConstants.dropHold {
                lock = nil
                weakSince = nil
            }
        } else {
            weakSince = t
        }
    }
}
