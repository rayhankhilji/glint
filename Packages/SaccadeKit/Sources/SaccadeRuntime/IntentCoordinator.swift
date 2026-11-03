import Foundation
import SaccadeCore
import SaccadePlatform

/// Joins gaze samples with the world under them and runs the `IntentEngine` (ARCHITECTURE §3, §6.1): fetches
/// Accessibility snapshots without blocking frames, reads window and input state, executes actions, and publishes
/// what the overlay should draw.
@MainActor
public final class IntentCoordinator {
    /// Called with every overlay state.
    public var onOverlay: @MainActor (OverlayState) -> Void = { _ in }
    /// Called when Saccade clicks a target by gaze, with the target's center: a drift-correction label.
    public var onTargetClicked: @MainActor (Point) -> Void = { _ in }
    /// Whether Saccade may act on other apps (Accessibility granted). Without it only the gaze dot shows.
    public var canAct = true
    /// The most recent actions, for diagnostics and tests.
    public private(set) var lastActions: [IntentAction] = []
    /// How long Accessibility snapshots take (milliseconds), for Settings → Advanced.
    public private(set) var snapshotLatency = LatencyWindow(capacity: 120)

    private var engine: IntentEngine
    private let targets: any TargetProviding
    private let performer: any ActionPerforming
    private let system: any SystemStateReading
    private var snapshot: TargetSnapshot?
    private var fetching = false
    private var windowCache: WindowState?

    /// Re-query Accessibility at most this often, or when the gaze moved this far.
    static let snapshotInterval: TimeInterval = 0.08
    static let snapshotMove = 24.0
    /// A snapshot only describes the area near where it was taken.
    static let snapshotReach = 160.0
    static let windowInterval: TimeInterval = 0.2

    public init(
        settings: Settings, targets: any TargetProviding, performer: any ActionPerforming,
        system: any SystemStateReading
    ) {
        engine = IntentEngine(settings: settings)
        self.targets = targets
        self.performer = performer
        self.system = system
    }

    public func update(settings: Settings) {
        engine.update(settings: settings)
    }

    /// Processes one gaze sample.
    public func handle(_ sample: GazeSample) {
        if let point = sample.point, canAct {
            requestSnapshot(near: point, sigma: sample.sigma, at: sample.t)
        }
        let world = makeWorld(for: sample)
        let (actions, overlay) = engine.step(sample: sample, world: world)
        lastActions = actions
        for action in actions where canAct {
            if case let .press(_, center) = action {
                onTargetClicked(center)
            }
            let performer = performer
            Task { await performer.execute(action) }
        }
        onOverlay(overlay)
    }

    /// Fetches a fresh snapshot now (tests and the first frame of a fixation use this directly).
    func refreshSnapshot(near point: Point, sigma: Double, at t: TimeInterval) async {
        let radius = SnapMachine.snapSigma(for: sigma) * IntentConstants.snapReachSigmas
        let started = ContinuousClock.now
        let result = await targets.snapshot(around: point, radius: radius)
        let elapsed = ContinuousClock.now - started
        snapshotLatency
            .append(Double(elapsed.components.attoseconds) / 1e15 + Double(elapsed.components.seconds) * 1000)
        snapshot = TargetSnapshot(point: point, t: t, candidates: result.candidates, scrollArea: result.scrollArea)
    }

    private func requestSnapshot(near point: Point, sigma: Double, at t: TimeInterval) {
        guard !fetching else { return }
        if let s = snapshot, t - s.t < Self.snapshotInterval, s.point.distance(to: point) < Self.snapshotMove {
            return
        }
        fetching = true
        Task { [weak self] in
            await self?.refreshSnapshot(near: point, sigma: sigma, at: t)
            self?.fetching = false
        }
    }

    private func makeWorld(for sample: GazeSample) -> WorldSnapshot {
        var world = WorldSnapshot()
        if let point = sample.point {
            if let s = snapshot, s.point.distance(to: point) <= Self.snapshotReach, canAct {
                world.candidates = s.candidates
                world.scrollArea = s.scrollArea
            }
            if windowCache.map({ sample.t - $0.t >= Self.windowInterval }) ?? true {
                windowCache = WindowState(
                    t: sample.t, window: system.window(at: point), focused: system.focusedWindowID(),
                    bundleID: system.frontmostBundleID()
                )
            }
        }
        world.windowUnderGaze = canAct ? windowCache?.window : nil
        world.focusedWindowID = windowCache?.focused
        world.appRule = windowCache?.bundleID.flatMap { engine.settings.rule(for: $0)?.mode }
        world.secondsSinceKeyDown = system.secondsSinceKeyDown
        world.secondsSincePointerMove = system.secondsSincePointerMove
        world.secondsSinceManualScroll = system.secondsSinceManualScroll
        world.mouseButtonDown = system.mouseButtonDown
        return world
    }
}

/// The Accessibility targets found around `point` at time `t`.
private struct TargetSnapshot {
    var point: Point
    var t: TimeInterval
    var candidates: [TargetCandidate]
    var scrollArea: ScrollAreaInfo?
}

/// Window and app state, refreshed a few times a second.
private struct WindowState {
    var t: TimeInterval
    var window: WindowInfo?
    var focused: Int?
    var bundleID: String?
}
