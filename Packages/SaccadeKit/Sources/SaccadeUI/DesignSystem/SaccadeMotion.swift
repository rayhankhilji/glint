import SwiftUI

/// Motion tokens (DESIGN_SYSTEM §6.1). Durations are seconds.
public enum SaccadeMotion {
    public static let instant: Double = 0.080
    public static let fast: Double = 0.140
    public static let base: Double = 0.220
    public static let slow: Double = 0.320
    public static let deliberate: Double = 0.520
    /// The longest motion allowed when Reduce Motion is on (DESIGN_SYSTEM §6.2).
    public static let reducedMax: Double = 0.150

    /// Cubic-bezier control points, usable outside SwiftUI (overlay, scroll glide).
    public struct Curve: Equatable, Sendable {
        public let c1x, c1y, c2x, c2y: Double

        public func animation(duration: Double) -> Animation {
            .timingCurve(c1x, c1y, c2x, c2y, duration: duration)
        }
    }

    public static let standard = Curve(c1x: 0.2, c1y: 0, c2x: 0, c2y: 1)
    public static let enter = Curve(c1x: 0, c1y: 0, c2x: 0, c2y: 1)
    public static let exit = Curve(c1x: 0.3, c1y: 0, c2x: 1, c2y: 1)
    public static let glide = Curve(c1x: 0.22, c1y: 0.61, c2x: 0.36, c2y: 1)

    public static var springFollow: Animation { .spring(response: 0.22, dampingFraction: 0.86) }
    public static var springAcquire: Animation { .spring(response: 0.28, dampingFraction: 0.78) }
    public static var springSnappy: Animation { .spring(response: 0.25, dampingFraction: 0.9) }
    public static var springGentle: Animation { .spring(response: 0.45, dampingFraction: 0.85) }
    public static var springCalibration: Animation { .spring(response: 0.9, dampingFraction: 1.0) }

    /// `animation`, or a ≤ 150 ms ease-out fade when Reduce Motion is on.
    public static func respecting(reduceMotion: Bool, _ animation: Animation) -> Animation {
        reduceMotion ? .easeOut(duration: reducedMax) : animation
    }
}
