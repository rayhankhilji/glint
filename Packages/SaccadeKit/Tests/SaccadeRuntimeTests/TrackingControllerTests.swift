import Foundation
import SaccadeCore
import SaccadeCoreTestSupport
import SaccadePerception
import SaccadePlatform
import SaccadeServices
import Testing
@testable import SaccadeRuntime

/// A camera stand-in: tests push synthetic observations straight into the controller.
final class FakeFaceTracker: FaceTracking, @unchecked Sendable {
    let observations: AsyncStream<FaceObservation?>
    var authorization: CameraAuthorization = .granted
    var startError: SaccadeError?
    private(set) var running = false

    init() {
        observations = AsyncStream { _ in }
    }

    func cameraAuthorization() -> CameraAuthorization {
        authorization
    }
    func requestCameraAccess() async -> Bool {
        authorization == .granted
    }

    func start() throws(SaccadeError) {
        if let startError {
            throw startError
        }
        running = true
    }

    func stop() {
        running = false
    }
}

@MainActor
@Suite("TrackingController")
struct TrackingControllerTests {
    private func makeController(
        _ tracker: FakeFaceTracker, root: URL, clock: ManualClock, enabled: Bool = true
    ) -> TrackingController {
        var settings = Settings.defaults(installID: Fixtures.installID)
        settings.isEnabled = enabled
        let controller = TrackingController(
            tracker: tracker, profiles: ProfileStore(paths: AppPaths(root: root)),
            settings: settings, pointsPerDegree: 47, clock: clock
        )
        controller.apply(settings: settings)
        return controller
    }

    @Test("Without calibration the camera runs and Saccade asks to calibrate")
    func notCalibrated() throws {
        let root = try TestSupport.makeTempRoot()
        defer { TestSupport.removeTempRoot(root) }
        let tracker = FakeFaceTracker()
        let controller = makeController(tracker, root: root, clock: ManualClock())
        #expect(tracker.running)
        #expect(controller.status == .needsAttention(.notCalibrated))
    }

    @Test("T-F10-AC1 (core): turning Saccade off stops the camera")
    func off() throws {
        let root = try TestSupport.makeTempRoot()
        defer { TestSupport.removeTempRoot(root) }
        let tracker = FakeFaceTracker()
        let controller = makeController(tracker, root: root, clock: ManualClock())
        var settings = Settings.defaults(installID: Fixtures.installID)
        settings.isEnabled = false
        controller.apply(settings: settings)
        #expect(!tracker.running)
        #expect(controller.status == .off)
    }

    @Test("Denied camera permission is reported and the camera stays off")
    func denied() throws {
        let root = try TestSupport.makeTempRoot()
        defer { TestSupport.removeTempRoot(root) }
        let tracker = FakeFaceTracker()
        tracker.authorization = .denied
        let controller = makeController(tracker, root: root, clock: ManualClock())
        #expect(!tracker.running)
        #expect(controller.status == .needsAttention(.cameraPermissionMissing))
    }

    @Test("No camera is reported as camera missing")
    func noCamera() throws {
        let root = try TestSupport.makeTempRoot()
        defer { TestSupport.removeTempRoot(root) }
        let tracker = FakeFaceTracker()
        tracker.startError = .cameraNotFound
        let controller = makeController(tracker, root: root, clock: ManualClock())
        #expect(controller.status == .needsAttention(.cameraMissing))
    }

    @Test("Calibrate end to end: result saved, survives relaunch, then live gaze and gestures")
    func calibrateAndTrack() throws {
        let root = try TestSupport.makeTempRoot()
        defer { TestSupport.removeTempRoot(root) }
        let clock = ManualClock()
        let controller = makeController(FakeFaceTracker(), root: root, clock: clock)
        var face = SyntheticFace(seed: 21)
        face.pupilNoise = 0.02
        try calibrate(controller, face: &face, clock: clock)
        #expect(controller.isCalibrated)
        #expect((controller.accuracyDegrees ?? 99) < 3)
        controller.endCalibration()

        // A relaunch loads the saved profile.
        #expect(makeController(FakeFaceTracker(), root: root, clock: clock).isCalibrated)

        // Live tracking follows the eyes.
        let target = Point(x: 300, y: 700)
        feed(controller, face: &face, clock: clock, target: target, frames: 45)
        let point = try #require(controller.latest?.point)
        #expect(point.distance(to: target) < 90, "\(point)")
        if case .tracking = controller.status {} else {
            Issue.record("status \(controller.status)")
        }

        // A double blink is reported as a gesture.
        var gestures: [BlinkGrammar.Gesture] = []
        controller.onGesture = { gesture, _ in gestures.append(gesture) }
        for (openness, frames) in [(0.04, 4), (0.32, 6), (0.04, 4), (0.32, 10)] {
            feed(controller, face: &face, clock: clock, target: target, frames: frames, openness: openness)
        }
        #expect(gestures == [.doubleBlink])

        // Five seconds without a face: away.
        for _ in 0 ..< 180 {
            controller.handle(nil)
            clock.advance(by: 1.0 / 30)
        }
        #expect(controller.status == .away)
    }

    @Test("A trace records header, model, frames and click labels, and replays to the same accuracy picture")
    func traceRecording() throws {
        let root = try TestSupport.makeTempRoot()
        defer { TestSupport.removeTempRoot(root) }
        let clock = ManualClock()
        let controller = makeController(FakeFaceTracker(), root: root, clock: clock)
        var face = SyntheticFace(seed: 22)
        face.pupilNoise = 0.02
        try calibrate(controller, face: &face, clock: clock)
        controller.endCalibration()

        var records: [TraceRecord] = []
        controller.beginTrace(screen: face.screenSize) { records.append($0) }
        for target in [Point(x: 400, y: 300), Point(x: 900, y: 600), Point(x: 1100, y: 250)] {
            feed(controller, face: &face, clock: clock, target: target, frames: 30)
            controller.learn(truth: target)
        }
        controller.traceSink = nil
        #expect(records.first?.header != nil)
        #expect(records.dropFirst().first?.model != nil)
        #expect(records.compactMap(\.frame).count == 90)
        #expect(records.compactMap(\.label).count == 3)
        #expect(controller.learnedLabels == 3)

        let report = TraceReplay().run(records)
        #expect(report.labels == 3 && report.unmatched == 0)
    }

    private func calibrate(_ controller: TrackingController, face: inout SyntheticFace, clock: ManualClock) throws {
        controller.beginCalibration(screenSize: face.screenSize)
        for _ in 0 ..< 1200 {
            let target = controller.calibration?.target ?? Point(x: 720, y: 450)
            controller.handle(face.observe(target: target, t: clock.now()))
            clock.advance(by: 1.0 / 30)
            if case .finished = controller.calibration?.phase {
                return
            }
        }
        Issue.record("calibration didn't finish: \(String(describing: controller.calibration?.phase))")
    }

    private func feed(
        _ controller: TrackingController, face: inout SyntheticFace, clock: ManualClock,
        target: Point, frames: Int, openness: Double = 0.32
    ) {
        for _ in 0 ..< frames {
            controller.handle(face.observe(target: target, t: clock.now(), openness: openness))
            clock.advance(by: 1.0 / 30)
        }
    }
}
