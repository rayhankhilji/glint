import Foundation

/// Pose-normalized eye measurements extracted from one `FaceObservation` (ARCHITECTURE §10.2).
///
/// Each eye gets its own frame: origin at the midpoint of its two corners, x along corner → corner, unit = half the
/// corner distance. The pupil is expressed in that frame, so head translation and distance mostly cancel out.
public struct GazeFeatures: Sendable, Equatable, Codable {
    /// Pupil position in the left/right eye frame (≈ -1...1).
    public var leftU: Double
    public var leftV: Double
    public var rightU: Double
    public var rightV: Double
    /// Head pose (radians); 0 when the provider has none.
    public var yaw: Double
    public var pitch: Double
    public var roll: Double
    /// Face center in the image, 0...1.
    public var faceX: Double
    public var faceY: Double
    /// Face width / image width: a distance proxy.
    public var faceScale: Double
    /// Eye openness: outline height / outline width, averaged over both eyes. Used for blinks, not for mapping.
    public var openness: Double

    /// The values fed to the gaze mapper, in a fixed order (`featureVersion` changes if this changes).
    public var mapperInputs: [Double] {
        [leftU, leftV, rightU, rightV, yaw, pitch, roll, faceX, faceY, faceScale]
    }

    public static let featureVersion = 1
    public static let mapperInputCount = 10

    public init(
        leftU: Double, leftV: Double, rightU: Double, rightV: Double, yaw: Double, pitch: Double, roll: Double,
        faceX: Double, faceY: Double, faceScale: Double, openness: Double
    ) {
        self.leftU = leftU
        self.leftV = leftV
        self.rightU = rightU
        self.rightV = rightV
        self.yaw = yaw
        self.pitch = pitch
        self.roll = roll
        self.faceX = faceX
        self.faceY = faceY
        self.faceScale = faceScale
        self.openness = openness
    }

    /// Extracts features, or returns `nil` when the observation can't support a gaze estimate (no pupils, degenerate
    /// eye outlines, or an empty image).
    public static func extract(from obs: FaceObservation) -> GazeFeatures? {
        guard obs.imageSize.width > 0, obs.imageSize.height > 0,
              let leftPupil = obs.leftIris ?? obs.leftPupil, let rightPupil = obs.rightIris ?? obs.rightPupil,
              let left = EyeFrame(outline: obs.leftEye), let right = EyeFrame(outline: obs.rightEye)
        else { return nil }
        let (lu, lv) = left.project(leftPupil)
        let (ru, rv) = right.project(rightPupil)
        let values = [lu, lv, ru, rv]
        guard values.allSatisfy({ $0.isFinite && abs($0) < 4 }) else { return nil }
        return GazeFeatures(
            leftU: lu, leftV: lv, rightU: ru, rightV: rv,
            yaw: obs.yaw ?? 0, pitch: obs.pitch ?? 0, roll: obs.roll ?? 0,
            faceX: obs.faceBounds.center.x / obs.imageSize.width,
            faceY: obs.faceBounds.center.y / obs.imageSize.height,
            faceScale: obs.faceBounds.width / obs.imageSize.width,
            openness: (left.openness + right.openness) / 2
        )
    }
}

/// The coordinate frame of one eye, built from its outline.
struct EyeFrame {
    let center: Point
    let axisX: Point
    let axisY: Point
    let halfWidth: Double
    let openness: Double

    init?(outline: [Point]) {
        guard outline.count >= 4,
              let inner = outline.min(by: { $0.x < $1.x }),
              let outer = outline.max(by: { $0.x < $1.x })
        else { return nil }
        let width = inner.distance(to: outer)
        guard width > 1e-6 else { return nil }
        let ax = (outer - inner) * (1 / width)
        let ay = Point(x: -ax.y, y: ax.x)
        // Outline extent perpendicular to the corner axis = lid opening.
        let offsets = outline.map { ($0 - inner).x * ay.x + ($0 - inner).y * ay.y }
        let height = (offsets.max() ?? 0) - (offsets.min() ?? 0)
        center = inner.interpolated(to: outer, t: 0.5)
        halfWidth = width / 2
        axisX = ax
        axisY = ay
        openness = height / width
    }

    /// Point expressed in this eye's frame, in half-widths.
    func project(_ p: Point) -> (Double, Double) {
        let d = p - center
        return ((d.x * axisX.x + d.y * axisX.y) / halfWidth, (d.x * axisY.x + d.y * axisY.y) / halfWidth)
    }
}
