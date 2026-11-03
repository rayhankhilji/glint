import SwiftUI

/// Shadow tokens with light and dark values (DESIGN_SYSTEM §5). Each token is two stacked shadows.
public enum SaccadeShadow: Sendable {
    case card, hud

    struct Layer {
        let opacity: Double
        let radius: CGFloat
        let y: CGFloat
    }

    func layers(for scheme: ColorScheme) -> [Layer] {
        let dark = scheme == .dark
        switch self {
        case .card:
            return [
                Layer(opacity: dark ? 0.40 : 0.06, radius: 2, y: 1),
                Layer(opacity: dark ? 0.35 : 0.08, radius: 24, y: 8),
            ]
        case .hud:
            return [Layer(opacity: dark ? 0.50 : 0.16, radius: 20, y: 6)]
        }
    }
}

struct SaccadeShadowModifier: ViewModifier {
    let token: SaccadeShadow
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        token.layers(for: colorScheme).reduce(AnyView(content)) { view, layer in
            AnyView(view.shadow(color: .black.opacity(layer.opacity), radius: layer.radius / 2, x: 0, y: layer.y))
        }
    }
}

public extension View {
    func saccadeShadow(_ token: SaccadeShadow) -> some View {
        modifier(SaccadeShadowModifier(token: token))
    }
}
