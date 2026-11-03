import SwiftUI

/// Every UI icon Saccade uses, mapped to SF Symbols (DESIGN_SYSTEM §7). SF Symbols match the system font's weight
/// and optical size and render perfectly at every scale; only the brand mark and menu bar glyphs are custom.
public enum SaccadeSymbol: String, CaseIterable, Sendable {
    case pause
    case resume = "play"
    case recalibrate = "scope"
    case settings = "gearshape"
    case quit = "power"
    case chevron = "chevron.right"
    case warning = "exclamationmark.triangle.fill"
    case info = "info.circle.fill"
    case camera
    case accessibility = "cursorarrow.click.2"
    case general = "slider.horizontal.3"
    case gestures = "eye"
    case scrolling = "arrow.down.to.line"
    case apps = "square.grid.2x2"
    case privacy = "hand.raised"
    case advanced = "gauge.with.dots.needle.33percent"
    case about = "info.circle"
    case check = "checkmark"
    case remove = "minus.circle"
    case off = "eye.slash"
    case record = "record.circle"
    case folder
}

/// An SF Symbol at Saccade's icon sizes, in the current foreground style.
public struct SaccadeSymbolImage: View {
    private let symbol: SaccadeSymbol
    private let size: CGFloat
    private let weight: Font.Weight

    public init(_ symbol: SaccadeSymbol, size: CGFloat = 13, weight: Font.Weight = .medium) {
        self.symbol = symbol
        self.size = size
        self.weight = weight
    }

    public var body: some View {
        Image(systemName: symbol.rawValue)
            .font(.system(size: size, weight: weight))
            .imageScale(.medium)
            .frame(width: size + 4, height: size + 4)
            .accessibilityHidden(true)
    }
}
