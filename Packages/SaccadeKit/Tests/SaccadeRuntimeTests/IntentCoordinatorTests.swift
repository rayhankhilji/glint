import Foundation
import SaccadeCore
import SaccadeCoreTestSupport
import Testing
@testable import SaccadeRuntime

final class FakeTargets: TargetProviding, @unchecked Sendable {
    var candidates: [TargetCandidate] = []
    var scrollArea: ScrollAreaInfo?
    func snapshot(
        around _: Point,
        radius _: Double
    ) async -> (candidates: [TargetCandidate], scrollArea: ScrollAreaInfo?) {
        (candidates, scrollArea)
    }
}

final class FakePerformer: ActionPerforming, @unchecked Sendable {
    func execute(_: IntentAction) async {}
}

@MainActor
final class FakeSystem: SystemStateReading {
    var windowUnderGaze: WindowInfo?
    var bundleID: String? = "com.apple.Safari"
    func window(at _: Point) -> WindowInfo? {
        windowUnderGaze
    }
    func focusedWindowID() -> Int? {
        1
    }
    func frontmostBundleID() -> String? {
        bundleID
    }
    var secondsSinceKeyDown: TimeInterval = 10
    var secondsSincePointerMove: TimeInterval = 10
    var secondsSinceManualScroll: TimeInterval = 10
    var mouseButtonDown = false
}

@MainActor
@Suite("IntentCoordinator")
struct IntentCoordinatorTests {
    let button = TargetCandidate(id: 7, frame: Rect(x: 400, y: 300, width: 90, height: 30), kind: .button)

    private func sample(_ p: Point?, t: Double, gesture: BlinkGrammar.Gesture? = nil) -> GazeSample {
        GazeSample(
            t: t,
            point: p,
            raw: p,
            uncorrected: p,
            fixating: true,
            sigma: 60,
            faceVisible: p != nil,
            confidence: 0.9,
            closure: 0,
            features: nil,
            blink: nil,
            gesture: gesture,
            armed: false
        )
    }

    @Test("Snaps to an AX target, clicks it on a double blink, and reports the click for learning")
    func snapAndClick() async {
        let targets = FakeTargets()
        targets.candidates = [button]
        let coordinator = IntentCoordinator(
            settings: Fixtures.settings(), targets: targets, performer: FakePerformer(), system: FakeSystem()
        )
        var overlays: [OverlayState] = []
        var learned: [Point] = []
        coordinator.onOverlay = { overlays.append($0) }
        coordinator.onTargetClicked = { learned.append($0) }
        let gaze = Point(x: 450, y: 340)
        await coordinator.refreshSnapshot(near: gaze, sigma: 60, at: 0)
        var t = 0.0
        for _ in 0 ..< 15 {
            coordinator.handle(sample(gaze, t: t))
            t += 1.0 / 30
        }
        #expect(overlays.last?.lock == button.frame)
        coordinator.handle(sample(gaze, t: t, gesture: .doubleBlink))
        #expect(coordinator.lastActions == [.press(targetID: 7, fallback: button.frame.center)])
        #expect(learned == [button.frame.center])
    }

    @Test("Without Accessibility only the gaze dot shows and nothing is executed")
    func noAccessibility() async {
        let targets = FakeTargets()
        targets.candidates = [button]
        let coordinator = IntentCoordinator(
            settings: Fixtures.settings(), targets: targets, performer: FakePerformer(), system: FakeSystem()
        )
        coordinator.canAct = false
        var last: OverlayState?
        coordinator.onOverlay = { last = $0 }
        let gaze = Point(x: 450, y: 340)
        await coordinator.refreshSnapshot(near: gaze, sigma: 60, at: 0)
        for i in 0 ..< 15 {
            coordinator.handle(sample(gaze, t: Double(i) / 30))
        }
        #expect(last?.lock == nil)
        #expect(last?.gazeDot == gaze)
    }

    @Test("Default app rules: no highlight in 1Password")
    func excludedApp() async {
        let targets = FakeTargets()
        targets.candidates = [button]
        let system = FakeSystem()
        system.bundleID = "com.1password.1password"
        let coordinator = IntentCoordinator(
            settings: Fixtures.settings(), targets: targets, performer: FakePerformer(), system: system
        )
        var last: OverlayState?
        coordinator.onOverlay = { last = $0 }
        await coordinator.refreshSnapshot(near: Point(x: 450, y: 340), sigma: 60, at: 0)
        for i in 0 ..< 15 {
            coordinator.handle(sample(Point(x: 450, y: 340), t: Double(i) / 30))
        }
        #expect(last?.lock == nil && last?.gazeDot == nil)
    }
}
