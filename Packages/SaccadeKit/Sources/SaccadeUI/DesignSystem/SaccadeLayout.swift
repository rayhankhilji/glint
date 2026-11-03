import CoreGraphics

/// Spacing scale, 4 pt base (DESIGN_SYSTEM §4).
public enum SaccadeSpacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let x3l: CGFloat = 48
    public static let hero: CGFloat = 64
}

/// Corner radii (DESIGN_SYSTEM §5).
public enum SaccadeRadius {
    public static let s: CGFloat = 6
    public static let m: CGFloat = 10
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 24

    /// Saccade ring radius for a target of `height` (DESIGN_SYSTEM §4): clamp(h × 0.28, 6, 14) + 4 pt outset.
    public static func saccadeRing(forTargetHeight height: CGFloat) -> CGFloat {
        min(max(height * 0.28, 6), 14) + SaccadeLayout.saccadeRingOutset
    }
}

/// Fixed layout metrics (DESIGN_SYSTEM §4).
public enum SaccadeLayout {
    public static let popoverWidth: CGFloat = 300
    /// Compact list row height (Linear-style density).
    public static let rowHeight: CGFloat = 28
    public static let onboardingSize = CGSize(width: 720, height: 520)
    public static let settingsMinSize = CGSize(width: 640, height: 480)
    public static let settingsLabelColumn: CGFloat = 180
    public static let formRowMinHeight: CGFloat = 44
    public static let hudHeight: CGFloat = 36
    public static let hudMaxWidth: CGFloat = 420
    public static let minHitTarget: CGFloat = 28
    public static let saccadeRingOutset: CGFloat = 4
    public static let saccadeRingMinSize = CGSize(width: 28, height: 28)
    public static let hairline: CGFloat = 0.5
    public static let focusRingWidth: CGFloat = 3
    public static let focusRingOffset: CGFloat = 2
}
