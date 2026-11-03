import SwiftUI

/// The only way to draw glass (INSTRUCTIONS §7, DESIGN_SYSTEM §5): Liquid Glass on macOS 26+, material plus a
/// solid edge hairline on 14–15, and an opaque raised surface when Reduce Transparency is on.
public struct GlassSurface<S: Shape, Content: View>: View {
    public enum Style: Sendable {
        case regular, clear
    }

    private let style: Style
    private let shape: S
    private let content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(style: Style = .regular, shape: S, @ViewBuilder content: () -> Content) {
        self.style = style
        self.shape = shape
        self.content = content()
    }

    public var body: some View {
        if reduceTransparency {
            content.background(SaccadeColor.surface, in: shape)
        } else if #available(macOS 26.0, *) {
            content.glassEffect(style == .clear ? .clear : .regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(SaccadeColor.border, lineWidth: SaccadeLayout.hairline))
        }
    }
}

public extension GlassSurface where S == RoundedRectangle {
    /// A rounded-rectangle glass surface, the common case.
    init(style: Style = .regular, cornerRadius: CGFloat, @ViewBuilder content: () -> Content) {
        self.init(
            style: style,
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            content: content
        )
    }
}
