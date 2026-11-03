import Foundation

/// The calibration flow as a pure state machine (PRD F-03, ARCHITECTURE §6.4). The UI shows `target` and
/// `progress`; the runtime feeds every frame's features. Time only advances at a target while the face is
/// visible, so looking away pauses calibration instead of spoiling it.
public struct CalibrationSession: Sendable {
    public enum Phase: Sendable, Equatable {
        case intro
        case collecting(index: Int)
        case finished(CalibrationResult)
        case failed(anchorsOK: Int)
    }

    /// Anchors as fractions of the screen, visited in a snake so the dot never jumps across the screen.
    public static let anchors: [Point] = [
        Point(x: 0.1, y: 0.1), Point(x: 0.5, y: 0.1), Point(x: 0.9, y: 0.1),
        Point(x: 0.9, y: 0.5), Point(x: 0.5, y: 0.5), Point(x: 0.1, y: 0.5),
        Point(x: 0.1, y: 0.9), Point(x: 0.5, y: 0.9), Point(x: 0.9, y: 0.9),
    ]
    public static let introDuration = 1.2
    /// Eyes need time to land on a new dot (saccade + provider latency); those frames are ignored.
    public static let settleDuration = 0.45
    public static let collectDuration = 1.0
    public static let minimumSamplesPerAnchor = 8
    public static let minimumAnchors = 6

    public let screenSize: Size
    public private(set) var phase: Phase = .intro
    public private(set) var samples: [CalibrationSample] = []
    private var introElapsed = 0.0
    private var anchorElapsed = 0.0
    private var lastTime: TimeInterval?
    private var anchorSampleCounts: [Int] = Array(repeating: 0, count: CalibrationSession.anchors.count)

    public init(screenSize: Size) {
        self.screenSize = screenSize
    }

    /// Screen point (top-left origin) of the current target, if collecting.
    public var target: Point? {
        guard case let .collecting(index) = phase else { return nil }
        return Self.point(for: index, in: screenSize)
    }

    /// 0...1 progress at the current target (0 while settling).
    public var progress: Double {
        guard case .collecting = phase else { return 0 }
        return ((anchorElapsed - Self.settleDuration) / Self.collectDuration).clamped(to: 0 ... 1)
    }

    public static func point(for index: Int, in size: Size) -> Point {
        let a = anchors[index]
        return Point(x: a.x * size.width, y: a.y * size.height)
    }

    /// Feeds one frame. `features == nil` means no usable face this frame.
    public mutating func ingest(features: GazeFeatures?, at t: TimeInterval) {
        let dt = lastTime.map { (t - $0).clamped(to: 0 ... 0.25) } ?? 0
        lastTime = t
        switch phase {
        case .intro:
            introElapsed += dt
            if introElapsed >= Self.introDuration {
                phase = .collecting(index: 0)
            }
        case let .collecting(index):
            guard let features else { return }
            anchorElapsed += dt
            if anchorElapsed >= Self.settleDuration {
                samples.append(CalibrationSample(
                    features: features.mapperInputs,
                    target: Self.point(for: index, in: screenSize),
                    group: index
                ))
                anchorSampleCounts[index] += 1
            }
            if anchorElapsed >= Self.settleDuration + Self.collectDuration {
                advance(from: index)
            }
        case .finished, .failed:
            break
        }
    }

    private mutating func advance(from index: Int) {
        anchorElapsed = 0
        if index + 1 < Self.anchors.count {
            phase = .collecting(index: index + 1)
            return
        }
        let goodAnchors = Set(anchorSampleCounts.indices
            .filter { anchorSampleCounts[$0] >= Self.minimumSamplesPerAnchor })
        let usable = samples.filter { goodAnchors.contains($0.group) }
        guard goodAnchors.count >= Self.minimumAnchors, let model = try? GazeMapper.fit(usable) else {
            phase = .failed(anchorsOK: goodAnchors.count)
            return
        }
        let errors = GazeMapper.leaveGroupOutErrors(usable, lambda: model.lambda)
        let median = GazeMapper.median(Array(errors.values))
        phase = .finished(CalibrationResult(model: model, medianErrorPoints: median, anchorsOK: goodAnchors.count))
    }
}

/// A finished calibration.
public struct CalibrationResult: Sendable, Equatable, Codable {
    public var model: MapperModel
    /// Median leave-one-anchor-out error in screen points.
    public var medianErrorPoints: Double
    public var anchorsOK: Int

    /// Converts the error to degrees of visual angle for a display with `pointsPerDegree` (≈ 40–60 on laptops).
    public func medianErrorDegrees(pointsPerDegree: Double) -> Double {
        pointsPerDegree > 0 ? medianErrorPoints / pointsPerDegree : .nan
    }
}
