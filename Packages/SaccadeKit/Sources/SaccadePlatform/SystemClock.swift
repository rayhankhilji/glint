import Foundation
import SaccadeCore

/// Production `Clock` backed by Swift's `ContinuousClock` (monotonic, keeps counting across sleep).
public struct SystemClock: Clock {
    private let origin = ContinuousClock.now

    public init() {}

    public func now() -> TimeInterval {
        let elapsed = origin.duration(to: ContinuousClock.now)
        return Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) * 1e-18
    }
}
