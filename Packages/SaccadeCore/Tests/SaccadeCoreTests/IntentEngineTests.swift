import Foundation
import SaccadeCoreTestSupport
import Testing
@testable import SaccadeCore

/// Helpers to drive the engine at 30 fps.
private struct Driver {
    var engine = IntentEngine(settings: Fixtures.settings())
    var t = 0.0
    var world = WorldSnapshot()

    mutating func frame(
        gaze: Point?, sigma: Double = 60, fixating: Bool = true, gesture: BlinkGrammar.Gesture? = nil,
        armed: Bool = false
    ) -> (actions: [IntentAction], overlay: OverlayState) {
        let sample = GazeSample(
            t: t, point: gaze, raw: gaze, uncorrected: gaze, fixating: fixating, sigma: sigma, faceVisible: gaze != nil,
            confidence: 0.9, closure: 0, features: nil, blink: nil, gesture: gesture, armed: armed
        )
        let out = engine.step(sample: sample, world: world)
        t += 1.0 / 30
        return out
    }

    mutating func hold(
        _ gaze: Point?,
        seconds: Double,
        sigma: Double = 60
    ) -> (actions: [IntentAction], overlay: OverlayState) {
        var last: (actions: [IntentAction], overlay: OverlayState) = ([], OverlayState())
        var all: [IntentAction] = []
        for _ in 0 ..< Int(seconds * 30) {
            last = frame(gaze: gaze, sigma: sigma)
            all += last.actions
        }
        return (all, last.overlay)
    }
}

private let saveButton = TargetCandidate(id: 1, frame: Rect(x: 400, y: 300, width: 80, height: 28), kind: .button)
private let cancelButton = TargetCandidate(id: 2, frame: Rect(x: 500, y: 300, width: 80, height: 28), kind: .button)

@Suite("Snapping")
struct SnapTests {
    @Test("T-F05-AC1: the highlight snaps to the button the gaze is near, even when it misses by 30 pt")
    func snapsToNearest() {
        var d = Driver()
        d.world.candidates = [saveButton, cancelButton]
        let out = d.hold(Point(x: 440, y: 345), seconds: 0.3)
        #expect(out.overlay.lock == saveButton.frame)
        #expect(out.overlay.gazeDot == nil)
    }

    @Test("Nothing nearby: a small gaze dot, no lock")
    func dotWhenNothing() {
        var d = Driver()
        d.world.candidates = [saveButton]
        let out = d.hold(Point(x: 1200, y: 800), seconds: 0.2)
        #expect(out.overlay.lock == nil)
        #expect(out.overlay.gazeDot == Point(x: 1200, y: 800))
    }

    @Test("T-F05-AC3: jitter between two adjacent buttons doesn't flicker the lock")
    func hysteresis() {
        var d = Driver()
        d.world.candidates = [saveButton, cancelButton]
        _ = d.hold(Point(x: 440, y: 314), seconds: 0.3)
        var changes = 0
        var last = d.frame(gaze: Point(x: 440, y: 314)).overlay.lock
        var rng = SeededGenerator(seed: 4)
        for _ in 0 ..< 60 { // 2 s of jitter around Save's right edge
            let lock = d.frame(gaze: Point(x: 470 + rng.nextGaussian(standardDeviation: 12), y: 314)).overlay.lock
            if lock != last, lock != nil {
                changes += 1
            }
            last = lock ?? last
        }
        #expect(changes <= 2, "\(changes) lock changes")
    }

    @Test("A clear move to the other button switches the lock within ~150 ms")
    func switches() {
        var d = Driver()
        d.world.candidates = [saveButton, cancelButton]
        _ = d.hold(Point(x: 440, y: 314), seconds: 0.3)
        let out = d.hold(Point(x: 545, y: 314), seconds: 0.2)
        #expect(out.overlay.lock == cancelButton.frame)
    }

    @Test("Gaze exactly between two equal buttons is uncertain: both faint, nothing locked")
    func uncertain() {
        var d = Driver()
        d.world.candidates = [saveButton, cancelButton]
        let out = d.hold(Point(x: 490, y: 314), seconds: 0.2)
        #expect(out.overlay.lock == nil)
        #expect(out.overlay.uncertain.count == 2)
    }

    @Test("Moving the mouse hides the gaze highlight (manual input wins)")
    func pointerWins() {
        var d = Driver()
        d.world.candidates = [saveButton]
        d.world.secondsSincePointerMove = 0.2
        let out = d.hold(Point(x: 440, y: 314), seconds: 0.2)
        #expect(out.overlay.lock == nil && out.overlay.gazeDot == nil)
    }
}

@Suite("Click, scroll, focus, reading")
struct IntentActionTests {
    @Test("T-F06-AC1: a double blink on a stable lock presses it, once")
    func click() {
        var d = Driver()
        d.world.candidates = [saveButton]
        _ = d.hold(Point(x: 440, y: 314), seconds: 0.4)
        let out = d.frame(gaze: Point(x: 440, y: 314), gesture: .doubleBlink)
        #expect(out.actions == [.press(targetID: 1, fallback: saveButton.frame.center)])
        #expect(out.overlay.clickCount == 1)
        #expect(d.frame(gaze: Point(x: 440, y: 314), gesture: .doubleBlink).actions.isEmpty) // cooldown
    }

    @Test("No click without a stable lock, while uncertain, or with the mouse button down")
    func clickGating() {
        var d = Driver()
        d.world.candidates = [saveButton]
        _ = d.hold(Point(x: 440, y: 314), seconds: 0.1)
        #expect(d.frame(gaze: Point(x: 440, y: 314), gesture: .doubleBlink).actions.isEmpty)
        var u = Driver()
        u.world.candidates = [saveButton, cancelButton]
        _ = u.hold(Point(x: 490, y: 314), seconds: 0.5)
        #expect(u.frame(gaze: Point(x: 490, y: 314), gesture: .doubleBlink).actions.isEmpty)
        var m = Driver()
        m.world.candidates = [saveButton]
        _ = m.hold(Point(x: 440, y: 314), seconds: 0.5)
        m.world.mouseButtonDown = true
        #expect(m.frame(gaze: Point(x: 440, y: 314), gesture: .doubleBlink).actions.isEmpty)
    }

    @Test("Blink + long blink opens the context menu")
    func rightClick() {
        var d = Driver()
        d.world.candidates = [saveButton]
        _ = d.hold(Point(x: 440, y: 314), seconds: 0.4)
        #expect(d.frame(gaze: Point(x: 440, y: 314), gesture: .blinkLongBlink).actions
            == [.showMenu(targetID: 1, fallback: saveButton.frame.center)])
    }

    @Test("T-F05-AC4: over empty space a double blink clicks only when \"Only click real controls\" is off")
    func freeClick() {
        let gaze = Point(x: 1200, y: 800)
        var precise = Driver()
        _ = precise.hold(gaze, seconds: 0.4)
        #expect(precise.frame(gaze: gaze, gesture: .doubleBlink).actions.isEmpty)
        var free = Driver()
        var settings = Fixtures.settings()
        settings.preciseTargetsOnly = false
        free.engine.update(settings: settings)
        _ = free.hold(gaze, seconds: 0.4)
        #expect(free.frame(gaze: gaze, fixating: false, gesture: .doubleBlink).actions.isEmpty) // mid-saccade
        #expect(free.frame(gaze: gaze, gesture: .doubleBlink).actions
            == [.press(targetID: IntentConstants.freeTargetID, fallback: gaze)])
    }

    @Test("The debug gaze point shows even over a locked target")
    func debugDot() {
        var d = Driver()
        var settings = Fixtures.settings()
        settings.debugGazeDot = true
        d.engine.update(settings: settings)
        d.world.candidates = [saveButton]
        let out = d.hold(Point(x: 440, y: 314), seconds: 0.3)
        #expect(out.overlay.lock == saveButton.frame)
        #expect(out.overlay.gazeDot == Point(x: 440, y: 314))
    }

    @Test("T-F07-AC1: resting in the bottom 15% glides down 40% after the dwell; the progress bar fills first")
    func glide() {
        var d = Driver()
        d.world.scrollArea = ScrollAreaInfo(frame: Rect(x: 0, y: 0, width: 1000, height: 800))
        let gaze = Point(x: 500, y: 760)
        let early = d.hold(gaze, seconds: 0.15)
        #expect(early.actions.isEmpty)
        #expect((early.overlay.scrollProgress?.progress ?? 0) > 0.3)
        let later = d.hold(gaze, seconds: 0.25)
        #expect(later.actions.contains(.glide(delta: 320, at: gaze, duration: IntentConstants.glideDuration)))
    }

    @Test("T-F07-AC3/AC4: no glide right after a manual scroll, or at the end of the page")
    func glideSuppressed() {
        var d = Driver()
        d.world.scrollArea = ScrollAreaInfo(frame: Rect(x: 0, y: 0, width: 1000, height: 800))
        d.world.secondsSinceManualScroll = 0.5
        #expect(d.hold(Point(x: 500, y: 760), seconds: 1).actions.isEmpty)
        var e = Driver()
        e.world.scrollArea = ScrollAreaInfo(frame: Rect(x: 0, y: 0, width: 1000, height: 800), canScrollDown: false)
        #expect(e.hold(Point(x: 500, y: 760), seconds: 1).actions.isEmpty)
    }

    @Test("Looking at the top 10% for 450 ms glides back up 30%")
    func glideUp() {
        var d = Driver()
        d.world.scrollArea = ScrollAreaInfo(frame: Rect(x: 0, y: 0, width: 1000, height: 800))
        let out = d.hold(Point(x: 500, y: 40), seconds: 0.6)
        #expect(out.actions.contains(.glide(
            delta: -240,
            at: Point(x: 500, y: 40),
            duration: IntentConstants.glideDuration
        )))
    }

    @Test("T-F08-AC1/AC2: focus follows a 900 ms gaze dwell, but not while typing")
    func focus() {
        let other = WindowInfo(id: 9, pid: 42, frame: Rect(x: 800, y: 0, width: 600, height: 800))
        var d = Driver()
        d.world.windowUnderGaze = other
        d.world.focusedWindowID = 3
        d.world.secondsSinceKeyDown = 0.4
        #expect(d.hold(Point(x: 1000, y: 400), seconds: 1.2).actions.isEmpty)
        d.world.secondsSinceKeyDown = 5
        #expect(d.hold(Point(x: 1000, y: 400), seconds: 1.0).actions == [.focus(window: other)])
    }

    @Test("T-F10-AC4: in an excluded app nothing is highlighted or done")
    func excludedApp() {
        var d = Driver()
        d.world.candidates = [saveButton]
        d.world.appRule = .off
        _ = d.hold(Point(x: 440, y: 314), seconds: 0.5)
        let out = d.frame(gaze: Point(x: 440, y: 314), gesture: .doubleBlink)
        #expect(out.actions.isEmpty && out.overlay.lock == nil && out.overlay.gazeDot == nil)
    }

    @Test("T-F09-AC1/AC3: after a ≥2 s break, the last read line is marked; a short glance isn't")
    func whereWasI() {
        var d = Driver()
        d.world.scrollArea = ScrollAreaInfo(frame: Rect(x: 0, y: 0, width: 1000, height: 800))
        d.world.windowUnderGaze = WindowInfo(id: 5, pid: 1, frame: Rect(x: 0, y: 0, width: 1000, height: 800))
        _ = d.hold(Point(x: 300, y: 420), seconds: 0.5)
        _ = d.hold(nil, seconds: 1.0)
        #expect(d.frame(gaze: Point(x: 600, y: 200)).overlay.lineMarker == nil)
        _ = d.hold(Point(x: 300, y: 420), seconds: 0.3)
        _ = d.hold(nil, seconds: 2.5)
        let marker = d.frame(gaze: Point(x: 600, y: 200)).overlay.lineMarker
        #expect(marker?.minY == 408)
        #expect(marker?.height == IntentConstants.lineBandHeight)
    }
}
