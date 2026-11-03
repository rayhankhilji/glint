import Foundation

/// Self-correcting gaze (ARCHITECTURE §10.7): every time the user's true point of regard is known (a mouse click,
/// a target they clicked with their eyes), the residual between the estimate and that point is remembered.
///
/// The correction is hierarchical:
/// - a **global shift** (the weighted mean of all residuals, shrunk toward zero) absorbs what moving or leaning does
///   to the whole map, so one or two clicks anywhere fix the entire screen;
/// - a **local field** (kernel-weighted residuals after removing the shift) fixes position-dependent errors the
///   mapper can't.
///
/// Every label is weighted by recency and by how similar the head pose was when it was learned, so corrections from
/// one sitting position don't leak into another.
public struct DriftCorrector: Sendable, Codable, Equatable {
    public struct Residual: Sendable, Codable, Equatable {
        public var at: Point
        public var offset: Point
        public var t: TimeInterval
        public var weight: Double
        public var pose: HeadPose?
    }

    /// Spatial reach of one label for the local field (points).
    public var kernelRadius = 260.0
    /// Labels fade with this time constant (seconds).
    public var halfLife: TimeInterval = 900
    /// Pseudo-count pulling the local field toward zero (higher = needs more evidence).
    public var shrinkage = 0.6
    /// Pseudo-count for the global shift: it takes a couple of agreeing labels to move the whole screen.
    public var globalShrinkage = 2.0
    /// Largest correction ever applied (points).
    public var maxOffset = 220.0
    public private(set) var residuals: [Residual] = []
    /// Error of the *corrected* estimate at each label, measured before learning from it (points): live accuracy.
    public private(set) var recentErrors: [Double] = []
    static let capacity = 80
    static let errorWindow = 15
    /// Live accuracy needs at least this many labels.
    public static let minimumErrorSamples = 5

    public init() {}

    /// Records that the user was looking at `truth` while the uncorrected estimate was `estimate` (head pose `pose`).
    /// Implausible labels (farther apart than `maxOffset`) are ignored: the user was probably looking elsewhere.
    public mutating func learn(
        estimate: Point, truth: Point, at t: TimeInterval, weight: Double = 1, pose: HeadPose? = nil
    ) {
        let offset = truth - estimate
        guard offset.length <= maxOffset, weight > 0 else { return }
        let corrected = estimate + correction(at: estimate, now: t, pose: pose)
        recentErrors.append(corrected.distance(to: truth))
        if recentErrors.count > Self.errorWindow {
            recentErrors.removeFirst(recentErrors.count - Self.errorWindow)
        }
        residuals.append(Residual(at: estimate, offset: offset, t: t, weight: weight, pose: pose))
        if residuals.count > Self.capacity {
            residuals.removeFirst(residuals.count - Self.capacity)
        }
    }

    /// The offset to add to an uncorrected estimate at `p`, for a user currently at head pose `pose`.
    public func correction(at p: Point, now t: TimeInterval, pose: HeadPose? = nil) -> Point {
        let base = residuals.map { r -> Double in
            let age = max(0, t - r.t)
            let similarity = (pose.flatMap { now in r.pose.map { now.similarity(to: $0) } }) ?? 1
            return r.weight * pow(0.5, age / halfLife) * similarity
        }
        var globalSum = Point.zero
        var globalTotal = 0.0
        for (r, w) in zip(residuals, base) {
            globalSum += r.offset * w
            globalTotal += w
        }
        guard globalTotal > 0 else { return .zero }
        let shift = globalSum * (1 / (globalTotal + globalShrinkage))

        var localSum = Point.zero
        var localTotal = 0.0
        for (r, w) in zip(residuals, base) {
            let d = p.distance(to: r.at)
            let lw = w * exp(-(d * d) / (2 * kernelRadius * kernelRadius))
            localSum += (r.offset - shift) * lw
            localTotal += lw
        }
        let local = localTotal > 0 ? localSum * (1 / (localTotal + shrinkage)) : .zero
        let c = shift + local
        return c.length > maxOffset ? c * (maxOffset / c.length) : c
    }

    /// Median error of the corrected estimate over the recent labels (points), once there are enough of them.
    public var liveErrorPoints: Double? {
        guard recentErrors.count >= Self.minimumErrorSamples else { return nil }
        let sorted = recentErrors.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    public mutating func reset() {
        residuals.removeAll()
        recentErrors.removeAll()
    }
}

/// Where the head is, from the features (for pose-aware corrections).
public struct HeadPose: Sendable, Codable, Equatable {
    public var faceX: Double
    public var faceY: Double
    public var faceScale: Double
    public var yaw: Double
    public var pitch: Double

    public init(faceX: Double, faceY: Double, faceScale: Double, yaw: Double = 0, pitch: Double = 0) {
        self.faceX = faceX
        self.faceY = faceY
        self.faceScale = faceScale
        self.yaw = yaw
        self.pitch = pitch
    }

    /// One standard deviation of face movement: 5% of the image width (about 3 cm at laptop distance).
    static let positionScale = 0.05
    /// 10% closer or farther.
    static let scaleScale = 0.1
    /// About 6° of head rotation.
    static let angleScale = 0.1

    /// 1 for the same pose, falling off as a Gaussian in normalized pose distance.
    public func similarity(to other: HeadPose) -> Double {
        let dx = (faceX - other.faceX) / Self.positionScale
        let dy = (faceY - other.faceY) / Self.positionScale
        let ratio = faceScale > 0 && other.faceScale > 0 ? log(faceScale / other.faceScale) : 0
        let ds = ratio / Self.scaleScale
        let dyaw = (yaw - other.yaw) / Self.angleScale
        let dpitch = (pitch - other.pitch) / Self.angleScale
        let d2 = dx * dx + dy * dy + ds * ds + dyaw * dyaw + dpitch * dpitch
        return exp(-d2 / 2)
    }
}

public extension GazeFeatures {
    var pose: HeadPose {
        HeadPose(faceX: faceX, faceY: faceY, faceScale: faceScale, yaw: yaw, pitch: pitch)
    }
}
