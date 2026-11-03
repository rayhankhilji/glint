import Foundation

/// The decision core (ARCHITECTURE §10.5): combines each gaze sample with the world under it and decides what to
/// highlight and what to do. Pure and deterministic. Fail-safe (G-ML-01): no point, no actions.
public struct IntentEngine: Sendable {
    public private(set) var settings: Settings
    public private(set) var snap = SnapMachine()
    private var overlay = OverlayState()
    private var lastClick: TimeInterval = -.infinity
    private var scrollDwellStart: TimeInterval?
    private var scrollTowardTop = false
    private var lastGlide: TimeInterval = -.infinity
    private var focusCandidate: (window: WindowInfo, since: TimeInterval)?
    private var lastFocus: TimeInterval = -.infinity
    private var reading: (point: Point, window: Int, t: TimeInterval)?
    private var breakStart: TimeInterval?
    private var markerShownFor: TimeInterval?

    public init(settings: Settings) {
        self.settings = settings
    }

    public mutating func update(settings: Settings) {
        self.settings = settings.validated()
    }

    /// The current lock (for drift-correction labels when the user clicks it).
    public var lockedTarget: TargetCandidate? { snap.lock?.candidate }

    public mutating func step(
        sample: GazeSample,
        world: WorldSnapshot
    ) -> (actions: [IntentAction], overlay: OverlayState) {
        let t = sample.t
        var actions: [IntentAction] = []
        overlay.windowFlash = nil
        overlay.lineMarker = markerShownFor.map { t - $0 < IntentConstants.lineMarkerDuration } == true ? overlay
            .lineMarker : nil

        guard let gaze = sample.point, sample.faceVisible, world.appRule != .off else {
            noteAttentionBreak(at: t, faceVisible: sample.faceVisible)
            clearGaze()
            return ([], overlay)
        }
        returnFromBreak(gaze: gaze, world: world, at: t)

        let scrollOnly = world.appRule == .scrollOnly
        let pointerActive = world.secondsSincePointerMove < IntentConstants.pointerHidesOverlay

        // Snap
        if scrollOnly || pointerActive {
            snap.reset()
        } else {
            snap.step(gaze: gaze, sigma: sample.sigma, candidates: world.candidates, at: t, frozen: sample.armed)
        }
        overlay.lock = snap.lock?.candidate.frame
        overlay.lockPhase = sample.armed ? .armed : .locked
        overlay.uncertain = snap.uncertain.map(\.frame)
        let idle = overlay.lock == nil && overlay.uncertain.isEmpty && !pointerActive && !scrollOnly
        overlay.gazeDot = (idle || settings.debugGazeDot) ? gaze : nil

        // Click
        if let gesture = sample.gesture, !scrollOnly,
           let action = click(gesture, gaze: gaze, fixating: sample.fixating, world: world, at: t) {
            actions.append(action)
        }
        // Scroll
        if let glide = scroll(gaze: gaze, fixating: sample.fixating, world: world, at: t) {
            actions.append(glide)
        }
        // Focus
        if !scrollOnly, let focus = focus(world: world, at: t) {
            actions.append(focus)
        }
        // Reading position
        if sample.fixating, let window = world.windowUnderGaze, world.scrollArea?.frame.contains(gaze) == true {
            reading = (gaze, window.id, t)
        }
        return (actions, overlay)
    }

    /// No usable gaze (or an excluded app): forget every in-progress intent and draw nothing gaze-related.
    private mutating func clearGaze() {
        snap.reset()
        scrollDwellStart = nil
        focusCandidate = nil
        overlay.lock = nil
        overlay.uncertain = []
        overlay.gazeDot = nil
        overlay.scrollProgress = nil
    }

    // MARK: Click (F-06)

    /// Clicks the locked target. With "Only click real controls" off, a fixation with no target clicks the gaze
    /// point itself (F-05); `freeTargetID` never matches an Accessibility element, so actuation falls back to a
    /// pointer click there.
    private mutating func click(
        _ gesture: BlinkGrammar.Gesture, gaze: Point, fixating: Bool, world: WorldSnapshot, at t: TimeInterval
    ) -> IntentAction? {
        guard settings.click.enabled, !world.mouseButtonDown, t - lastClick >= IntentConstants.clickCooldown
        else { return nil }
        let id: Int
        let point: Point
        if let lock = snap.lock {
            guard t - lock.since >= IntentConstants.clickLockStable else { return nil }
            id = lock.candidate.id
            point = lock.candidate.frame.center
        } else {
            guard !settings.preciseTargetsOnly, fixating, snap.uncertain.isEmpty else { return nil }
            id = IntentConstants.freeTargetID
            point = gaze
        }
        switch gesture {
        case .doubleBlink:
            lastClick = t
            overlay.clickCount += 1
            return .press(targetID: id, fallback: point)
        case .blinkLongBlink:
            guard settings.click.rightClickEnabled else { return nil }
            lastClick = t
            overlay.clickCount += 1
            return .showMenu(targetID: id, fallback: point)
        }
    }

    // MARK: Scroll (F-07)

    private mutating func scroll(
        gaze: Point,
        fixating: Bool,
        world: WorldSnapshot,
        at t: TimeInterval
    ) -> IntentAction? {
        overlay.scrollProgress = nil
        guard settings.scroll.enabled, let area = world.scrollArea, area.frame.contains(gaze),
              world.secondsSinceManualScroll >= IntentConstants.manualScrollSuspend,
              t - lastGlide >= IntentConstants.scrollCooldown, fixating
        else {
            scrollDwellStart = nil
            return nil
        }
        let f = area.frame
        let inBottom = gaze.y >= f.maxY - f.height * settings.scroll.downZoneFraction && area.canScrollDown
        let inTop = gaze.y <= f.minY + f.height * settings.scroll.upZoneFraction && area.canScrollUp
        guard inBottom || inTop else {
            scrollDwellStart = nil
            return nil
        }
        if scrollDwellStart == nil || scrollTowardTop != inTop {
            scrollDwellStart = t
            scrollTowardTop = inTop
        }
        let dwell = inTop ? IntentConstants.scrollUpDwell : Double(settings.scroll.dwellMs) / IntentConstants
            .millisecondsPerSecond
        let progress = ((t - (scrollDwellStart ?? t)) / dwell).clamped(to: 0 ... 1)
        overlay.scrollProgress = (f, progress, inTop)
        guard progress >= 1 else { return nil }
        scrollDwellStart = nil
        lastGlide = t
        overlay.scrollProgress = nil
        let distance = f.height * (inTop ? -IntentConstants.scrollUpFraction : settings.scroll.glideFraction)
        return .glide(delta: distance, at: gaze, duration: IntentConstants.glideDuration)
    }

    // MARK: Focus (F-08)

    private mutating func focus(world: WorldSnapshot, at t: TimeInterval) -> IntentAction? {
        guard settings.focusFollowsGaze.enabled, let window = world.windowUnderGaze,
              window.id != world.focusedWindowID,
              world.secondsSinceKeyDown >= IntentConstants.focusTypingGuard, !world.mouseButtonDown,
              t - lastFocus >= IntentConstants.focusCooldown
        else {
            focusCandidate = nil
            return nil
        }
        guard let candidate = focusCandidate, candidate.window.id == window.id else {
            focusCandidate = (window, t)
            return nil
        }
        guard t - candidate.since >= Double(settings.focusFollowsGaze.dwellMs) / IntentConstants.millisecondsPerSecond
        else { return nil }
        focusCandidate = nil
        lastFocus = t
        overlay.windowFlash = window.frame
        return .focus(window: window)
    }

    // MARK: Where was I (F-09)

    private mutating func noteAttentionBreak(at t: TimeInterval, faceVisible _: Bool) {
        if breakStart == nil {
            breakStart = t
        }
    }

    private mutating func returnFromBreak(gaze: Point, world: WorldSnapshot, at t: TimeInterval) {
        defer { breakStart = nil }
        guard settings.readingMarkerEnabled, let start = breakStart, let last = reading,
              t - start >= IntentConstants.readingBreak, t - last.t <= IntentConstants.readingReturnWindow,
              world.windowUnderGaze?.id == last.window, world.secondsSinceManualScroll > t - start,
              let area = world.scrollArea
        else { return }
        let band = IntentConstants.lineBandHeight
        overlay.lineMarker = Rect(
            x: area.frame.minX + IntentConstants.lineInset, y: last.point.y - band * IntentConstants.half,
            width: area.frame.width - IntentConstants.lineInset - IntentConstants.lineInset, height: band
        )
        markerShownFor = t
    }
}
