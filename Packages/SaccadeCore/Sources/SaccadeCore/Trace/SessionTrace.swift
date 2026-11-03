import Foundation

/// A features-only session recording (ARCHITECTURE §10.6, `saccade-trace/v2`): per-frame eye measurements, the
/// calibration model in use, and ground-truth labels from clicks. It never contains images, landmarks of other
/// apps, or screen content, so it can be replayed offline to tune the pipeline (`saccade-eval --trace`).
///
/// JSON Lines: one `TraceRecord` per line, exactly one of its fields set.
public struct TraceRecord: Codable, Sendable, Equatable {
    public var header: TraceHeader?
    public var model: MapperModel?
    public var frame: TraceFrame?
    public var label: TraceLabel?

    public static func header(_ value: TraceHeader) -> TraceRecord {
        TraceRecord(header: value)
    }
    public static func model(_ value: MapperModel) -> TraceRecord {
        TraceRecord(model: value)
    }
    public static func frame(_ value: TraceFrame) -> TraceRecord {
        TraceRecord(frame: value)
    }
    public static func label(_ value: TraceLabel) -> TraceRecord {
        TraceRecord(label: value)
    }

    public init(
        header: TraceHeader? = nil,
        model: MapperModel? = nil,
        frame: TraceFrame? = nil,
        label: TraceLabel? = nil
    ) {
        self.header = header
        self.model = model
        self.frame = frame
        self.label = label
    }
}

public struct TraceHeader: Codable, Sendable, Equatable {
    public static let currentFormat = "saccade-trace/v2"
    public var format: String
    public var featureVersion: Int
    public var screen: Size
    public var pointsPerDegree: Double

    public init(screen: Size, pointsPerDegree: Double) {
        format = Self.currentFormat
        featureVersion = GazeFeatures.featureVersion
        self.screen = screen
        self.pointsPerDegree = pointsPerDegree
    }
}

public struct TraceFrame: Codable, Sendable, Equatable {
    public var t: TimeInterval
    public var features: GazeFeatures?
    public var confidence: Double
    public var faceVisible: Bool

    public init(t: TimeInterval, features: GazeFeatures?, confidence: Double, faceVisible: Bool) {
        self.t = t
        self.features = features
        self.confidence = confidence
        self.faceVisible = faceVisible
    }
}

/// Where the user was really looking at `t`: a physical click (weight 1) or a target clicked by gaze (lower).
public struct TraceLabel: Codable, Sendable, Equatable {
    public var t: TimeInterval
    public var truth: Point
    public var weight: Double

    public init(t: TimeInterval, truth: Point, weight: Double) {
        self.t = t
        self.truth = truth
        self.weight = weight
    }
}

public enum SessionTrace {
    /// One JSON line (no trailing newline).
    public static func encodeLine(_ record: TraceRecord) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(record), let line = String(bytes: data, encoding: .utf8) else {
            return "{}"
        }
        return line
    }

    /// Parses JSON Lines; blank lines are skipped, a malformed line throws.
    public static func decode(_ text: String) throws -> [TraceRecord] {
        let decoder = JSONDecoder()
        return try text.split(whereSeparator: \.isNewline).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            return try decoder.decode(TraceRecord.self, from: Data(trimmed.utf8))
        }
    }
}
