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

/// Accuracy level as text plus a small dot (DESIGN_SYSTEM §8). The text always names the level, so color is
/// never the only signal.
public struct AccuracyChip: View {
    private let reading: AccuracyReading?

    public init(reading: AccuracyReading?) {
        self.reading = reading
    }

    public var body: some View {
        HStack(spacing: GlintSpacing.xs) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text(title)
                .glintText(.caption)
                .foregroundStyle(GlintColor.text)
            if let reading {
                Text(Self.degrees(reading.medianErrorDegrees))
                    .glintText(.caption)
                    .monospacedDigit()
                    .foregroundStyle(GlintColor.textMuted)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var title: String {
        guard let reading else { return String(localized: "Not calibrated", bundle: .module) }
        switch reading.level {
        case .excellent: return String(localized: "Excellent", bundle: .module)
        case .good: return String(localized: "Good", bundle: .module)
        case .fair: return String(localized: "Fair", bundle: .module)
        case .poor: return String(localized: "Poor", bundle: .module)
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
        let value = reading.medianErrorDegrees.formatted(.number.precision(.fractionLength(1)))
        return String(localized: "Accuracy: \(title), \(value) degrees", bundle: .module)
    }

    /// One decimal and a degree sign, e.g. "2.1°" (DESIGN_SYSTEM §10).
    static func degrees(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US_POSIX"))) + "°"
    }
}
