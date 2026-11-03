import SwiftUI

/// Draws a Saccade icon at `size` points in the current foreground style (DESIGN_SYSTEM §7).
/// Decorative by default; pass `label` when the icon is the only content of a control.
public struct SaccadeIcon: View {
    private let name: SaccadeIconName
    private let size: CGFloat
    private let label: String?

    public init(_ name: SaccadeIconName, size: CGFloat = 16, label: String? = nil) {
        self.name = name
        self.size = size
        self.label = label
    }

    public var body: some View {
        SaccadeArtworkView(artwork: name.artwork, size: size)
            .accessibilityHidden(label == nil)
            .accessibilityLabel(label.map { Text($0) } ?? Text(verbatim: ""))
    }
}

/// Renders artwork parts. `transform` lets animated icons move, scale or trim individual parts.
struct SaccadeArtworkView: View {
    let artwork: SaccadeIconArtwork
    let size: CGFloat
    var transform: (SaccadeIconPart) -> PartAppearance = { _ in PartAppearance() }

    var body: some View {
        ZStack {
            ForEach(Array(artwork.parts.enumerated()), id: \.offset) { _, part in
                let look = transform(part)
                let path = part.path(side: size, grid: artwork.grid)
                Group {
                    switch part.style {
                    case .fill:
                        path.fill()
                    case .stroke:
                        path.trimmedPath(from: 0, to: look.drawProgress).stroke(style: artwork.strokeStyle(side: size))
                    }
                }
                .opacity(look.opacity)
                .scaleEffect(look.scale, anchor: look.anchor(part: part, grid: artwork.grid))
                .rotationEffect(look.rotation, anchor: look.anchor(part: part, grid: artwork.grid))
                .scaleEffect(
                    x: 1,
                    y: look.scaleY,
                    anchor: look.squashAnchor ?? look.anchor(part: part, grid: artwork.grid)
                )
            }
        }
        .frame(width: size, height: size)
    }
}

/// Per-part animation state. Anchors default to the part's own center so a sparkle twinkles in place.
struct PartAppearance {
    var opacity: Double = 1
    var scale: CGFloat = 1
    var scaleY: CGFloat = 1
    var rotation: Angle = .zero
    var drawProgress: CGFloat = 1
    /// Anchor for `scaleY` only (e.g. `.center` to squash parts toward the icon center like a closing lid).
    /// `scale` and `rotation` always use the part's own center, so a catchlight swells in place.
    var squashAnchor: UnitPoint?

    func anchor(part: SaccadeIconPart, grid: CGFloat) -> UnitPoint {
        let b = part.gridBounds
        guard !b.isNull else { return .center }
        return UnitPoint(x: b.midX / grid, y: b.midY / grid)
    }
}
