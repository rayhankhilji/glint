import Foundation
import SaccadeCore

/// Generates `FaceObservation`s for a known gaze target (TESTING_GUIDE §4.1), so the feature → calibration →
/// mapping chain can be tested end to end without a camera. The eye model is deliberately nonlinear (pupil offset
/// ∝ sin of the eye-in-head angle) and pose-dependent, like a real eye.
public struct SyntheticFace: Sendable {
    public var screenSize = Size(width: 1440, height: 900)
    /// Viewing distance in points (≈ 60 cm on a 14" laptop).
    public var distance = 1300.0
    public var imageSize = Size(width: 640, height: 480)
    /// Pupil noise as a fraction of the eye half-width (provider jitter).
    public var pupilNoise = 0.0
    /// Random head motion (radians of yaw/pitch, pixels of translation) per observation.
    public var headJitter = 0.0
    public var rng: SeededGenerator

    public init(seed: UInt64 = 1) {
        rng = SeededGenerator(seed: seed)
    }

    /// An observation of a face looking at `target` (screen points, top-left origin).
    public mutating func observe(
        target: Point, t: TimeInterval, yaw: Double = 0, pitch: Double = 0, openness: Double = 0.32
    ) -> FaceObservation {
        let yaw = yaw + rng.nextGaussian(standardDeviation: headJitter)
        let pitch = pitch + rng.nextGaussian(standardDeviation: headJitter)
        // Gaze angles from the head (assumed centered in front of the screen) to the target.
        let gazeX = atan((target.x - screenSize.width / 2) / distance)
        let gazeY = atan((target.y - screenSize.height / 2) / distance)
        // Eye-in-head rotation: the head turn carries part of the gaze.
        let eyeX = sin(gazeX - yaw * 0.9) * 2.2
        let eyeY = sin(gazeY - pitch * 0.9) * 1.6 + 0.08 * eyeX * eyeX
        // Face placement in the image moves with head pose (camera above the screen).
        let faceCenter = Point(
            x: imageSize.width / 2 - yaw * 260 + rng.nextGaussian(standardDeviation: headJitter * 40),
            y: imageSize.height * 0.45 + pitch * 200 + rng.nextGaussian(standardDeviation: headJitter * 40)
        )
        let faceWidth = 210.0
        let eyeWidth = faceWidth * 0.22
        let eyes = [-1.0, 1.0].map { side -> (outline: [Point], pupil: Point) in
            let center = faceCenter + Point(x: side * faceWidth * 0.21, y: -faceWidth * 0.08)
            let outline = (0 ..< 8).map { i -> Point in
                let a = Double(i) / 8 * 2 * .pi
                return center + Point(x: cos(a) * eyeWidth / 2, y: sin(a) * eyeWidth / 2 * openness * 2)
            }
            let noise = Point(
                x: rng.nextGaussian(standardDeviation: pupilNoise),
                y: rng.nextGaussian(standardDeviation: pupilNoise)
            )
            let offset = Point(x: eyeX * 0.25 + noise.x, y: eyeY * 0.25 + noise.y) * (eyeWidth / 2)
            return (outline, center + offset)
        }
        return FaceObservation(
            timestamp: t, imageSize: imageSize, leftEye: eyes[0].outline, rightEye: eyes[1].outline,
            leftPupil: eyes[0].pupil, rightPupil: eyes[1].pupil,
            faceBounds: Rect(
                x: faceCenter.x - faceWidth / 2,
                y: faceCenter.y - faceWidth * 0.6,
                width: faceWidth,
                height: faceWidth * 1.2
            ),
            yaw: yaw, pitch: pitch, roll: 0, confidence: 0.95
        )
    }

    /// Runs a full calibration at 30 fps and returns the finished session.
    public mutating func calibrate(fps: Double = 30) -> CalibrationSession {
        var session = CalibrationSession(screenSize: screenSize)
        var t = 0.0
        while t < 60 {
            let target = session.target ?? Point(x: screenSize.width / 2, y: screenSize.height / 2)
            let obs = observe(target: target, t: t)
            session.ingest(features: GazeFeatures.extract(from: obs), at: t)
            if case .finished = session.phase {
                break
            }
            if case .failed = session.phase {
                break
            }
            t += 1 / fps
        }
        return session
    }
}
