import SwiftUI

/// The Glint mark: a ring (the eye) with an accent catchlight (DESIGN_SYSTEM §7). Its motions are quiet and
/// brief; every one has a static Reduce Motion fallback.
public struct GlintMark: View {
    public enum Motion: Sendable {
        /// No motion.
        case still
        /// Live: every 8 s the catchlight brightens and swells slightly (popover header while tracking).
        case live
        /// Teaching loop: the ring blinks twice, then the catchlight pulses (onboarding, Playground).
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
        .accessibilityHidden(true)
    }

    private func draw(_ pose: MarkPose) -> some View {
        let art = GlintIconName.mark.artwork
        return ZStack {
            GlintArtworkView(artwork: art, size: size) { part in
                part.id == "ring" ? PartAppearance(scaleY: pose.lid, squashAnchor: .center) : PartAppearance(opacity: 0)
            }
            .foregroundStyle(GlintColor.text)
            GlintArtworkView(artwork: art, size: size) { part in
                part.id == "catchlight"
                    // Squashes with the lid toward the eye's center, then swells on its own center.
                    ? PartAppearance(
                        opacity: pose.catchlightOpacity,
                        scale: pose.catchlightScale,
                        scaleY: pose.lid,
                        squashAnchor: .center
                    )
                    : PartAppearance(opacity: 0)
            }
            .foregroundStyle(GlintColor.accent)
        }
    }

    /// 8 s cycle: rest, then a 500 ms swell (scale 1 → 1.3 → 1) with the opacity dipping and returning.
    @KeyframesBuilder<MarkPose>
    private static var live: some Keyframes<MarkPose> {
        KeyframeTrack(\.catchlightScale) {
            LinearKeyframe(1, duration: 7.5)
            CubicKeyframe(1.3, duration: 0.2)
            SpringKeyframe(1, duration: 0.3, spring: .snappy)
        }
    }

    /// 2.6 s loop: open → blink (80 ms close, 120 ms open) → 180 ms gap → blink → catchlight pulse → rest.
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
        KeyframeTrack(\.catchlightScale) {
            LinearKeyframe(1, duration: 1.18)
            CubicKeyframe(1.5, duration: 0.14)
            SpringKeyframe(1, duration: 0.4, spring: .snappy)
            LinearKeyframe(1, duration: 0.88)
        }
    }
}

/// Animatable pose of the mark's parts.
struct MarkPose {
    var lid: CGFloat = 1
    var catchlightScale: CGFloat = 1
    var catchlightOpacity: Double = 1
}
