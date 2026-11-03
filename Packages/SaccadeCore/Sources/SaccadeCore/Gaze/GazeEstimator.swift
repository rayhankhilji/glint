import Foundation

/// One processed frame (ARCHITECTURE §4 GazeSample).
public struct GazeSample: Sendable, Equatable {
    public var t: TimeInterval
    /// Best gaze estimate in screen points (top-left origin), when calibrated and a face is visible:
    /// stabilized and drift-corrected.
    public var point: Point?
    /// The mapper's per-frame output before stabilization and drift correction.
    public var raw: Point?
    /// Stabilized but uncorrected point: what drift-correction labels are measured against.
    public var uncorrected: Point?
    /// Whether the eyes are resting on one spot (≥ 100 ms).
    public var fixating: Bool
    /// 1σ uncertainty radius in points.
    public var sigma: Double
    public var faceVisible: Bool
    public var confidence: Double
    /// Eye closure 0...1.
    public var closure: Double
    public var features: GazeFeatures?
    public var blink: Blink?
    public var gesture: BlinkGrammar.Gesture?
    /// First blink of a possible double blink seen.
    public var armed: Bool

    public init(
        t: TimeInterval, point: Point?, raw: Point?, uncorrected: Point?, fixating: Bool, sigma: Double,
        faceVisible: Bool, confidence: Double, closure: Double, features: GazeFeatures?, blink: Blink?,
        gesture: BlinkGrammar.Gesture?, armed: Bool
    ) {
        self.t = t
        self.point = point
        self.raw = raw
        self.uncorrected = uncorrected
        self.fixating = fixating
        self.sigma = sigma
        self.faceVisible = faceVisible
        self.confidence = confidence
        self.closure = closure
        self.features = features
        self.blink = blink
        self.gesture = gesture
        self.armed = armed
    }
}

/// Frame-by-frame gaze pipeline: features → calibrated mapper → spike filter → fixation stabilizer → learned drift
/// correction, plus blink detection. Pure and deterministic: feed it observations with their timestamps.
public struct GazeEstimator: Sendable {
    public private(set) var model: MapperModel?
    /// Below this provider confidence a frame is treated as "no face" (G-ML-01).
    public var minimumConfidence = 0.5
    public private(set) var drift = DriftCorrector()
    private var filter = PointFilter(minCutoff: 1.2, beta: 0.004)
    private var stabilizer = FixationStabilizer()
    private var blinks = BlinkDetector()
    private var grammar = BlinkGrammar()
    private var lastPoint: Point?
    private var lastUncorrected: Point?
    private var lastPose: HeadPose?

    public init(model: MapperModel? = nil) {
        self.model = model
    }

    public mutating func setModel(_ model: MapperModel?) {
        self.model = model
        filter.reset()
        stabilizer.reset()
        drift.reset()
        lastPoint = nil
        lastUncorrected = nil
        lastPose = nil
    }

    /// Replaces the drift corrector (trace replay tries different tunables).
    public mutating func setDrift(_ drift: DriftCorrector) {
        self.drift = drift
    }

    /// Teaches the drift corrector that the user was looking at `truth` (screen points) at time `t`, measured
    /// against the most recent uncorrected estimate. Call for mouse clicks and for targets the user confirmed.
    public mutating func learn(truth: Point, at t: TimeInterval, weight: Double = 1) {
        guard let estimate = lastUncorrected else { return }
        drift.learn(estimate: estimate, truth: truth, at: t, weight: weight, pose: lastPose)
    }

    public mutating func ingest(_ obs: FaceObservation?, at t: TimeInterval) -> GazeSample {
        let features = obs.flatMap { $0.confidence >= minimumConfidence ? GazeFeatures.extract(from: $0) : nil }
        return ingest(features: features, confidence: obs?.confidence ?? 0, faceVisible: obs != nil, at: t)
    }

    /// The pipeline from features on: used by `ingest(_:at:)` and by trace replay (`saccade-eval`).
    public mutating func ingest(
        features: GazeFeatures?, confidence: Double, faceVisible: Bool, at t: TimeInterval
    ) -> GazeSample {
        grammar.expire(at: t, eyesClosed: blinks.isClosed)
        guard let features, confidence >= minimumConfidence else {
            _ = blinks.ingest(openness: nil, at: t)
            filter.reset()
            stabilizer.reset()
            lastPoint = nil
            return GazeSample(
                t: t, point: nil, raw: nil, uncorrected: nil, fixating: false, sigma: 0, faceVisible: faceVisible,
                confidence: confidence, closure: 0, features: nil, blink: nil, gesture: nil,
                armed: grammar.isArmed
            )
        }
        let (closure, blink) = blinks.ingest(openness: features.openness, at: t)
        let gesture = blink.flatMap { grammar.ingest($0) }
        let sigma = model?.uncertainty(confidence: confidence) ?? 0

        var raw: Point?
        var point = lastPoint
        // While the lids are closing, the iris estimate is unreliable: hold the last point instead.
        if let model, closure < blinks.closedThreshold / 2 {
            let predicted = model.predict(features.mapperInputs)
            raw = predicted
            let stabilized = stabilizer.ingest(filter.filter(predicted, at: t), sigma: sigma, at: t)
            lastUncorrected = stabilized
            lastPose = features.pose
            point = stabilized + drift.correction(at: stabilized, now: t, pose: features.pose)
            lastPoint = point
        }
        return GazeSample(
            t: t, point: model == nil ? nil : point, raw: raw, uncorrected: lastUncorrected,
            fixating: stabilizer.isFixating(at: t), sigma: sigma,
            faceVisible: true, confidence: confidence, closure: closure,
            features: features, blink: blink, gesture: gesture, armed: grammar.isArmed
        )
    }
}
