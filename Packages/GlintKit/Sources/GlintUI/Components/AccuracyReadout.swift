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

/// Accuracy as plain text: level word (in its semantic color) and degrees in tabular digits (DESIGN_SYSTEM §8).
/// No pill: the word itself carries the state, so color is never the only signal.
public struct AccuracyReadout: View {
    private let reading: AccuracyReading?

    public init(reading: AccuracyReading?) {
        self.reading = reading
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: GlintSpacing.s) {
            Text(Self.levelTitle(reading?.level))
                .glintText(.bodyEmphasis)
                .foregroundStyle(tint)
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
        case nil: String(localized: "Not calibrated", bundle: .module)
        case .excellent: String(localized: "Excellent", bundle: .module)
        case .good: String(localized: "Good", bundle: .module)
        case .fair: String(localized: "Fair", bundle: .module)
        case .poor: String(localized: "Poor", bundle: .module)
        }
    }

    private var tint: Color {
        switch reading?.level {
        case .excellent, .good: GlintColor.success
        case .fair: GlintColor.warning
        case .poor: GlintColor.danger
        case nil: GlintColor.textMuted
        }
    }

    private var accessibilityText: String {
        guard let reading else { return String(localized: "Accuracy: not calibrated", bundle: .module) }
        let level = Self.levelTitle(reading.level)
        let value = reading.medianErrorDegrees.formatted(.number.precision(.fractionLength(1)))
        return String(localized: "Accuracy: \(level), \(value) degrees", bundle: .module)
    }

    /// One decimal and a degree sign, e.g. "2.1°" (DESIGN_SYSTEM §10).
    static func degrees(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US_POSIX"))) + "°"
    }
}
