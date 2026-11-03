import GlintCore
import SwiftUI

/// The latest calibration result shown to the user.
public struct AccuracyReading: Equatable, Sendable {
    public let level: AccuracyLevel
    public let medianErrorDegrees: Double

    public init(level: AccuracyLevel, medianErrorDegrees: Double) {
        self.level = level
        self.medianErrorDegrees = medianErrorDegrees
    }

    public init(medianErrorDegrees: Double) {
        self.init(level: AccuracyLevel(medianErrorDegrees: medianErrorDegrees), medianErrorDegrees: medianErrorDegrees)
    }
}

/// A 6 pt status dot (Linear-style). Always paired with a text label: color is never the only signal.
public struct StatusDot: View {
    private let color: Color

    public init(_ color: Color) {
        self.color = color
    }

    public var body: some View {
        Circle().fill(color).frame(width: 6, height: 6).accessibilityHidden(true)
    }
}

/// Accuracy as "● Good  2.1°": a status dot, the level word, and degrees in tabular digits (DESIGN_SYSTEM §8).
public struct AccuracyReadout: View {
    private let reading: AccuracyReading?

    public init(reading: AccuracyReading?) {
        self.reading = reading
    }

    public var body: some View {
        HStack(spacing: GlintSpacing.s) {
            StatusDot(Self.color(for: reading?.level))
            Text(Self.levelTitle(reading?.level))
                .glintText(.body)
                .foregroundStyle(GlintColor.text)
            if let reading {
                Text(Self.degrees(reading.medianErrorDegrees))
                    .glintText(.body)
                    .monospacedDigit()
                    .foregroundStyle(GlintColor.textMuted)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    static func levelTitle(_ level: AccuracyLevel?) -> String {
        switch level {
        case nil: String(localized: "Not calibrated")
        case .excellent: String(localized: "Excellent")
        case .good: String(localized: "Good")
        case .fair: String(localized: "Fair")
        case .poor: String(localized: "Poor")
        }
    }

    static func color(for level: AccuracyLevel?) -> Color {
        switch level {
        case .excellent, .good: GlintColor.success
        case .fair: GlintColor.warning
        case .poor: GlintColor.danger
        case nil: GlintColor.textFaint
        }
    }

    private var accessibilityText: String {
        guard let reading else { return String(localized: "Accuracy: not calibrated") }
        let level = Self.levelTitle(reading.level)
        let value = reading.medianErrorDegrees.formatted(.number.precision(.fractionLength(1)))
        return String(localized: "Accuracy: \(level), \(value) degrees")
    }

    /// One decimal and a degree sign, e.g. "2.1°" (DESIGN_SYSTEM §10).
    static func degrees(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US_POSIX"))) + "°"
    }
}

/// An inline callout for a problem that blocks Glint, with one fix action (DESIGN_SYSTEM §8).
public struct StatusBanner: View {
    public enum Kind: Sendable {
        case info, warning, danger
    }

    private let kind: Kind
    private let message: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(kind: Kind, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.kind = kind
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .top, spacing: GlintSpacing.s) {
            GlintSymbolImage(kind == .info ? .info : .warning, size: 11)
                .foregroundStyle(tint)
            Text(message)
                .glintText(.callout)
                .foregroundStyle(GlintColor.text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(GlintButtonStyle(.ghostAccent))
            }
        }
        .padding(.horizontal, GlintSpacing.m)
        .padding(.vertical, GlintSpacing.s)
        .background(GlintColor.subtle, in: RoundedRectangle(cornerRadius: GlintRadius.s, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        switch kind {
        case .info: GlintColor.accent
        case .warning: GlintColor.warning
        case .danger: GlintColor.danger
        }
    }
}

/// A quiet empty state: one symbol, a title and one sentence.
public struct EmptyState: View {
    private let symbol: GlintSymbol
    private let title: String
    private let message: String

    public init(symbol: GlintSymbol, title: String, message: String) {
        self.symbol = symbol
        self.title = title
        self.message = message
    }

    public var body: some View {
        VStack(spacing: GlintSpacing.s) {
            GlintSymbolImage(symbol, size: 20, weight: .regular)
                .foregroundStyle(GlintColor.textFaint)
                .padding(.bottom, GlintSpacing.xs)
            Text(title)
                .glintText(.bodyEmphasis)
                .foregroundStyle(GlintColor.text)
            Text(message)
                .glintText(.callout)
                .foregroundStyle(GlintColor.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .padding(GlintSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Buttons (DESIGN_SYSTEM §8): compact 28 pt controls with 6 pt corners. No gradients, no shadows.
public struct GlintButtonStyle: ButtonStyle {
    public enum Kind: Sendable {
        /// Accent fill, for the single main action in a view.
        case primary
        /// Hairline outline on surface.
        case secondary
        /// Text-only accent action (inline "Fix", "Help").
        case ghostAccent
    }

    private let kind: Kind
    @Environment(\.isEnabled) private var isEnabled

    public init(_ kind: Kind) {
        self.kind = kind
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .glintText(.bodyEmphasis)
            .foregroundStyle(foreground)
            .padding(.horizontal, kind == .ghostAccent ? GlintSpacing.xs : GlintSpacing.m)
            .frame(minHeight: kind == .ghostAccent ? 20 : GlintLayout.rowHeight)
            .background(
                background(pressed: configuration.isPressed),
                in: RoundedRectangle(cornerRadius: GlintRadius.s, style: .continuous)
            )
            .overlay {
                if kind == .secondary {
                    RoundedRectangle(cornerRadius: GlintRadius.s, style: .continuous)
                        .strokeBorder(GlintColor.border, lineWidth: 1)
                }
            }
            .opacity(isEnabled ? (configuration.isPressed && kind == .ghostAccent ? 0.6 : 1) : 0.4)
            .contentShape(Rectangle())
    }

    private var foreground: Color {
        switch kind {
        case .primary: GlintColor.onAccent
        case .secondary: GlintColor.text
        case .ghostAccent: GlintColor.accent
        }
    }

    private func background(pressed: Bool) -> Color {
        switch kind {
        case .primary: GlintColor.accent.opacity(pressed ? 0.85 : 1)
        case .secondary: pressed ? GlintColor.subtle : GlintColor.surface
        case .ghostAccent: .clear
        }
    }
}
