import Foundation

/// Replays a `saccade-trace/v2` recording through the production `GazeEstimator` and measures, at every label, how
/// far each stage's estimate was from the truth (before learning from that label, exactly as live).
public struct TraceReplay: Sendable {
    /// Errors (points) of one pipeline stage across all labels.
    public struct Stage: Sendable, Equatable {
        public var errors: [Double] = []

        public var median: Double? { percentile(50) }
        public var p90: Double? { percentile(90) }

        func percentile(_ p: Double) -> Double? {
            guard !errors.isEmpty else { return nil }
            let sorted = errors.sorted()
            let rank = Int((p / 100 * Double(sorted.count)).rounded(.up))
            return sorted[max(rank, 1) - 1]
        }
    }

    public struct Report: Sendable, Equatable {
        public var frames = 0
        public var labels = 0
        /// Labels with no estimate at that moment (no face, mid-blink, not calibrated).
        public var unmatched = 0
        public var pointsPerDegree = 1.0
        /// Mapper output, before filtering.
        public var mapper = Stage()
        /// After One Euro + fixation stabilization.
        public var stabilized = Stage()
        /// After drift correction: what the user saw.
        public var corrected = Stage()
    }

    /// Learn from labels (silent learning on) or only measure.
    public var learns = true
    /// Tunables under test.
    public var drift = DriftCorrector()

    public init() {}

    public func run(_ records: [TraceRecord]) -> Report {
        var report = Report()
        var estimator = GazeEstimator(model: records.lazy.compactMap(\.model).last)
        estimator.setDrift(drift)
        var latest: GazeSample?
        for record in records {
            if let header = record.header {
                report.pointsPerDegree = header.pointsPerDegree
            }
            if let model = record.model {
                estimator.setModel(model)
                estimator.setDrift(drift)
            }
            if let frame = record.frame {
                report.frames += 1
                latest = estimator.ingest(
                    features: frame.features, confidence: frame.confidence, faceVisible: frame.faceVisible, at: frame.t
                )
            }
            if let label = record.label {
                report.labels += 1
                guard let sample = latest, let point = sample.point, let raw = sample.raw,
                      let stabilized = sample.uncorrected
                else {
                    report.unmatched += 1
                    continue
                }
                report.mapper.errors.append(raw.distance(to: label.truth))
                report.stabilized.errors.append(stabilized.distance(to: label.truth))
                report.corrected.errors.append(point.distance(to: label.truth))
                if learns, sample.fixating {
                    estimator.learn(truth: label.truth, at: label.t, weight: label.weight)
                }
            }
        }
        return report
    }
}
