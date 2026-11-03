import SwiftUI

/// The Saccade mark: a fixation dot, the jump, and the ring it lands in (DESIGN_SYSTEM §7). Pure monochrome:
/// every part draws in the current text color. Motions are quiet and brief; each has a static Reduce Motion
/// fallback.
public struct SaccadeMark: View {
    public enum Motion: Sendable {
        /// No motion.
        case still
        /// Live: every 8 s the jump redraws from the dot to the ring (popover header while tracking).
        case live
        /// Teaching loop: the ring blinks twice, then the dot pulses (onboarding).
        case doubleBlink
    }

    private let size: CGFloat
    private let motion: Motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(size: CGFloat = 20, motion: Motion = .still) {
        self.size = size
        self.motion = motion
    }

    public var body: some View {
        Group {
            if reduceMotion || motion == .still {
                draw(MarkPose())
            } else if motion == .live {
                KeyframeAnimator(initialValue: MarkPose(), repeating: true) { pose in
                    draw(pose)
                } keyframes: { _ in
                    Self.live
                }
            } else {
                KeyframeAnimator(initialValue: MarkPose(), repeating: true) { pose in
                    draw(pose)
                } keyframes: { _ in
                    Self.doubleBlink
                }
            }
        }
        .foregroundStyle(SaccadeColor.text)
        .accessibilityHidden(true)
    }

    private func draw(_ pose: MarkPose) -> some View {
        SaccadeArtworkView(artwork: SaccadeIconName.mark.artwork, size: size) { part in
            switch part.id {
            case "ring": PartAppearance(scaleY: pose.lid)
            case "dot": PartAppearance(scale: pose.dotScale)
            case "path": PartAppearance(drawProgress: pose.jump)
            default: PartAppearance()
            }
        }
    }

    /// 8 s cycle: rest, then the jump retracts and redraws in 360 ms while the dot dips and recovers.
    @KeyframesBuilder<MarkPose>
    private static var live: some Keyframes<MarkPose> {
        KeyframeTrack(\.jump) {
            LinearKeyframe(1, duration: 7.4)
            CubicKeyframe(0, duration: 0.14)
            CubicKeyframe(1, duration: 0.22)
            LinearKeyframe(1, duration: 0.24)
        }
        KeyframeTrack(\.dotScale) {
            LinearKeyframe(1, duration: 7.4)
            CubicKeyframe(0.8, duration: 0.14)
            SpringKeyframe(1, duration: 0.46, spring: .snappy)
        }
    }

    /// 2.6 s loop: open → blink (80 ms close, 120 ms open) → 180 ms gap → blink → dot pulse → rest.
    @KeyframesBuilder<MarkPose>
    private static var doubleBlink: some Keyframes<MarkPose> {
        KeyframeTrack(\.lid) {
            LinearKeyframe(1, duration: 0.6)
            CubicKeyframe(0.06, duration: 0.08)
            CubicKeyframe(1, duration: 0.12)
            LinearKeyframe(1, duration: 0.18)
            CubicKeyframe(0.06, duration: 0.08)
            CubicKeyframe(1, duration: 0.12)
            LinearKeyframe(1, duration: 1.42)
        }
        KeyframeTrack(\.dotScale) {
            LinearKeyframe(1, duration: 1.18)
            CubicKeyframe(1.35, duration: 0.14)
            SpringKeyframe(1, duration: 0.4, spring: .snappy)
            LinearKeyframe(1, duration: 0.88)
        }
    }
}

/// Animatable pose of the mark's parts.
struct MarkPose {
    var lid: CGFloat = 1
    var dotScale: CGFloat = 1
    var jump: CGFloat = 1
}
