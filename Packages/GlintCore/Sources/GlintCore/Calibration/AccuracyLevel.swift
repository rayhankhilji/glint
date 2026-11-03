/// Calibration quality buckets shown to users (PRD F-03, DESIGN_SYSTEM §8 AccuracyChip).
public enum AccuracyLevel: String, Sendable, Codable, CaseIterable {
    case excellent, good, fair, poor

    /// Upper bounds (inclusive) of each bucket, in degrees of median validation error.
    public static let excellentMaxDegrees = 1.5
    public static let goodMaxDegrees = 2.5
    public static let fairMaxDegrees = 3.5

    /// Buckets a median angular error. Non-finite or negative input is treated as `.poor`.
    public init(medianErrorDegrees error: Double) {
        guard error.isFinite, error >= 0 else {
            self = .poor
            return
        }
        switch error {
        case ...Self.excellentMaxDegrees: self = .excellent
        case ...Self.goodMaxDegrees: self = .good
        case ...Self.fairMaxDegrees: self = .fair
        default: self = .poor
        }
    }

    /// Whether the result card should recommend recalibrating (F-03: Poor → "Let's try again").
    public var recommendsRetry: Bool { self == .poor }
}
