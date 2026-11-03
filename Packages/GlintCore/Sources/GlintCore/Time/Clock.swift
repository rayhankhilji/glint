import Foundation

/// Monotonic time source. GlintCore never reads the wall clock directly (INSTRUCTIONS §6); production code
/// injects a `mach_continuous_time`-based clock from GlintPlatform, and tests and replays use `ManualClock`.
public protocol Clock: Sendable {
    /// Seconds since an arbitrary, fixed origin. Monotonically non-decreasing.
    func now() -> TimeInterval
}

/// A clock that only moves when told to. Used by tests and by `glint-eval` replays, which is what makes
/// replays bit-identical (G-ML-06).
public final class ManualClock: Clock, @unchecked Sendable {
    // @unchecked: all access to `current` goes through `lock`.
    private let lock = NSLock()
    private var current: TimeInterval

    public init(start: TimeInterval = 0) {
        current = start
    }

    public func now() -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    /// Moves time forward. Negative durations are ignored so the clock stays monotonic.
    public func advance(by seconds: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        current += max(0, seconds)
    }

    /// Sets the time, never moving backwards.
    public func set(_ time: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        current = max(current, time)
    }
}
