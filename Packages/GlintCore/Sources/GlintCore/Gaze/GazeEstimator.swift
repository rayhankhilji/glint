import Foundation

/// One processed frame (ARCHITECTURE §4 GazeSample).
public struct GazeSample: Sendable, Equatable {
    public var t: TimeInterval
    /// Smoothed gaze point in screen points (top-left origin), when calibrated and a face is visible.
    public var point: Point?
    public var raw: Point?
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
}

/// Frame-by-frame gaze pipeline: features → calibrated mapper → One Euro smoothing, plus blink detection.
/// Pure and deterministic: feed it observations with their timestamps.
public struct GazeEstimator: Sendable {
    public private(set) var model: MapperModel?
    /// Below this provider confidence a frame is treated as "no face" (G-ML-01).
    public var minimumConfidence = 0.5
    private var filter = PointFilter()
    private var blinks = BlinkDetector()
    private var grammar = BlinkGrammar()
    private var lastPoint: Point?

    public init(model: MapperModel? = nil) {
        self.model = model
    }

    public mutating func setModel(_ model: MapperModel?) {
        self.model = model
        filter.reset()
        lastPoint = nil
    }

    public mutating func ingest(_ obs: FaceObservation?, at t: TimeInterval) -> GazeSample {
        grammar.expire(at: t, eyesClosed: blinks.isClosed)
        guard let obs, obs.confidence >= minimumConfidence, let features = GazeFeatures.extract(from: obs) else {
            _ = blinks.ingest(openness: nil, at: t)
            filter.reset()
            lastPoint = nil
            return GazeSample(
                t: t,
                point: nil,
                raw: nil,
                sigma: 0,
                faceVisible: obs != nil,
                confidence: obs?.confidence ?? 0,
                closure: 0,
                features: nil,
                blink: nil,
                gesture: nil,
                armed: grammar.isArmed
            )
        }
        let (closure, blink) = blinks.ingest(openness: features.openness, at: t)
        let gesture = blink.flatMap { grammar.ingest($0) }

        var raw: Point?
        var point = lastPoint
        // While the lids are closing, the pupil estimate is unreliable: hold the last point instead.
        if let model, closure < blinks.closedThreshold / 2 {
            let predicted = model.predict(features.mapperInputs)
            raw = predicted
            point = filter.filter(predicted, at: t)
            lastPoint = point
        }
        return GazeSample(
            t: t, point: model == nil ? nil : point, raw: raw,
            sigma: model?.uncertainty(confidence: obs.confidence) ?? 0,
            faceVisible: true, confidence: obs.confidence, closure: closure,
            features: features, blink: blink, gesture: gesture, armed: grammar.isArmed
        )
    }
}
