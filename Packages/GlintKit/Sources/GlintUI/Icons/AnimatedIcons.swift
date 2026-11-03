import SwiftUI

/// The Glint mark (eye + glint) with its signature motions (DESIGN_SYSTEM §6.2, Design/Motion/*.svg).
/// Every motion has a static Reduce Motion fallback.
public struct GlintMark: View {
    public enum Motion: Sendable {
        /// No motion.
        case still
        /// Live: the glint twinkles once every 12 s (popover header while tracking).
        case twinkle
        /// Teaching loop: the eye double-blinks, then the glint flares (onboarding, Playground).
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
            } else if motion == .twinkle {
                KeyframeAnimator(initialValue: MarkPose(), repeating: true) { pose in
                    draw(pose)
                } keyframes: { _ in
                    Self.twinkle
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
        GlintArtworkView(artwork: GlintIconName.eyeGlint.artwork, size: size) { part in
            switch part.id {
            case "sparkle":
                PartAppearance(
                    opacity: pose.sparkleOpacity,
                    scale: pose.sparkleScale,
                    rotation: .degrees(pose.sparkleSpin)
                )
            case "outline", "iris":
                PartAppearance(scaleY: pose.lid)
            default:
                PartAppearance()
            }
        }
        .foregroundStyle(GlintColor.text)
        .overlay {
            // The glint is the one warm element: recolor only the sparkle part.
            GlintArtworkView(artwork: GlintIconName.eyeGlint.artwork, size: size) { part in
                part.id == "sparkle"
                    ? PartAppearance(
                        opacity: pose.sparkleOpacity,
                        scale: pose.sparkleScale,
                        rotation: .degrees(pose.sparkleSpin)
                    )
                    : PartAppearance(opacity: 0)
            }
            .foregroundStyle(GlintColor.glintMark)
        }
    }

    /// 12 s cycle: 11.4 s rest, then a 600 ms twinkle (scale 1 → 1.25 → 1, a quarter turn). The glint is 4-fold
    /// symmetric, so the 90° → 0° reset at the loop is invisible (a 45° turn would snap).
    @KeyframesBuilder<MarkPose>
    private static var twinkle: some Keyframes<MarkPose> {
        KeyframeTrack(\.sparkleScale) {
            LinearKeyframe(1, duration: 11.4)
            CubicKeyframe(1.25, duration: 0.24)
            SpringKeyframe(1, duration: 0.36, spring: .snappy)
        }
        KeyframeTrack(\.sparkleSpin) {
            LinearKeyframe(0, duration: 11.4)
            CubicKeyframe(90, duration: 0.6)
            LinearKeyframe(0, duration: 0.001)
        }
    }

    /// 2.8 s teaching loop: open → blink (80 ms close, 120 ms open) → 180 ms gap → blink → flare → rest.
    @KeyframesBuilder<MarkPose>
    private static var doubleBlink: some Keyframes<MarkPose> {
        KeyframeTrack(\.lid) {
            LinearKeyframe(1, duration: 0.6)
            CubicKeyframe(0.08, duration: 0.08)
            CubicKeyframe(1, duration: 0.12)
            LinearKeyframe(1, duration: 0.18)
            CubicKeyframe(0.08, duration: 0.08)
            CubicKeyframe(1, duration: 0.12)
            LinearKeyframe(1, duration: 1.62)
        }
        KeyframeTrack(\.sparkleScale) {
            LinearKeyframe(1, duration: 1.18)
            CubicKeyframe(1.45, duration: 0.12)
            SpringKeyframe(1, duration: 0.5, spring: .bouncy)
            LinearKeyframe(1, duration: 1.0)
        }
        KeyframeTrack(\.sparkleOpacity) {
            LinearKeyframe(0.55, duration: 0.6)
            LinearKeyframe(0.55, duration: 0.2)
            LinearKeyframe(0.85, duration: 0.38)
            CubicKeyframe(1, duration: 0.12)
            LinearKeyframe(1, duration: 0.9)
            CubicKeyframe(0.55, duration: 0.6)
        }
    }
}

/// Animatable pose of the mark's parts.
struct MarkPose {
    var lid: CGFloat = 1
    var sparkleScale: CGFloat = 1
    var sparkleSpin: Double = 0
    var sparkleOpacity: Double = 1
}

/// An icon whose strokes draw on once when it appears (permission granted, calibration done).
public struct DrawOnIcon: View {
    private let name: GlintIconName
    private let size: CGFloat
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(_ name: GlintIconName, size: CGFloat = 20) {
        self.name = name
        self.size = size
    }

    public var body: some View {
        GlintArtworkView(artwork: name.artwork, size: size) { _ in PartAppearance(drawProgress: progress) }
            .accessibilityHidden(true)
            .onAppear {
                if reduceMotion {
                    progress = 1
                } else {
                    withAnimation(GlintMotion.standard.animation(duration: 0.28)) { progress = 1 }
                }
            }
    }
}
