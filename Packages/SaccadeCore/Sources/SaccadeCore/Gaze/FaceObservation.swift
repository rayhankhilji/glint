import Foundation

/// One camera frame's face measurement, independent of the landmark provider (Apple Vision today; MediaPipe
/// later). Points are in image pixels with a top-left origin. Pixel data never reaches this type (G-SEC-01).
public struct FaceObservation: Sendable, Equatable {
    public var timestamp: TimeInterval
    public var imageSize: Size
    /// Eye outline points, in any order (at least 4 each).
    public var leftEye: [Point]
    public var rightEye: [Point]
    /// Pupil centers from the landmark model (coarse), when the provider found them.
    public var leftPupil: Point?
    public var rightPupil: Point?
    /// Iris centers measured from the eye pixels by `IrisLocator` (sub-pixel). Preferred over the pupils.
    public var leftIris: Point?
    public var rightIris: Point?
    /// Face bounding box in image pixels.
    public var faceBounds: Rect
    /// Head pose in radians, when available.
    public var yaw: Double?
    public var pitch: Double?
    public var roll: Double?
    /// 0...1 provider confidence.
    public var confidence: Double

    public init(
        timestamp: TimeInterval, imageSize: Size, leftEye: [Point], rightEye: [Point],
        leftPupil: Point?, rightPupil: Point?, leftIris: Point? = nil, rightIris: Point? = nil, faceBounds: Rect,
        yaw: Double? = nil, pitch: Double? = nil, roll: Double? = nil, confidence: Double
    ) {
        self.timestamp = timestamp
        self.imageSize = imageSize
        self.leftEye = leftEye
        self.rightEye = rightEye
        self.leftPupil = leftPupil
        self.rightPupil = rightPupil
        self.leftIris = leftIris
        self.rightIris = rightIris
        self.faceBounds = faceBounds
        self.yaw = yaw
        self.pitch = pitch
        self.roll = roll
        self.confidence = confidence
    }
}
