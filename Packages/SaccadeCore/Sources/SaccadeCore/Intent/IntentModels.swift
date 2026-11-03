import Foundation

/// An actionable UI element near the gaze (from the Accessibility tree).
public struct TargetCandidate: Sendable, Equatable {
    public enum Kind: String, Sendable {
        case button, link, menuItem, checkbox, tab, popUp, textField, cell, other
    }

    /// Stable within one AX snapshot registry; used to address the element for actions.
    public var id: Int
    public var frame: Rect
    public var kind: Kind
    public var canPress: Bool
    public var canShowMenu: Bool
    public var pid: Int32

    public init(id: Int, frame: Rect, kind: Kind, canPress: Bool = true, canShowMenu: Bool = false, pid: Int32 = 0) {
        self.id = id
        self.frame = frame
        self.kind = kind
        self.canPress = canPress
        self.canShowMenu = canShowMenu
        self.pid = pid
    }
}

/// The scroll area under the gaze.
public struct ScrollAreaInfo: Sendable, Equatable {
    public var frame: Rect
    public var canScrollUp: Bool
    public var canScrollDown: Bool

    public init(frame: Rect, canScrollUp: Bool = true, canScrollDown: Bool = true) {
        self.frame = frame
        self.canScrollUp = canScrollUp
        self.canScrollDown = canScrollDown
    }
}

/// An on-screen window.
public struct WindowInfo: Sendable, Equatable {
    public var id: Int
    public var pid: Int32
    public var frame: Rect

    public init(id: Int, pid: Int32, frame: Rect) {
        self.id = id
        self.pid = pid
        self.frame = frame
    }
}

/// Everything the intent engine knows about the world this frame (ARCHITECTURE §4 WorldSnapshot).
public struct WorldSnapshot: Sendable, Equatable {
    public var candidates: [TargetCandidate] = []
    public var scrollArea: ScrollAreaInfo?
    public var windowUnderGaze: WindowInfo?
    public var focusedWindowID: Int?
    /// The frontmost app's rule; `nil` means no restrictions.
    public var appRule: AppRuleMode?
    public var secondsSinceKeyDown: TimeInterval = .infinity
    public var secondsSincePointerMove: TimeInterval = .infinity
    public var secondsSinceManualScroll: TimeInterval = .infinity
    public var mouseButtonDown = false

    public init() {}
}

/// What the engine asks the system layer to do.
public enum IntentAction: Sendable, Equatable {
    case press(targetID: Int, fallback: Point)
    case showMenu(targetID: Int, fallback: Point)
    /// Scroll the content under `at` by `delta` points (positive = content moves up, i.e. reveal what's below).
    case glide(delta: Double, at: Point, duration: TimeInterval)
    case focus(window: WindowInfo)
}

/// What the overlay should draw this frame (DESIGN_SYSTEM §6.2).
public struct OverlayState: Sendable, Equatable {
    public enum LockPhase: Sendable, Equatable {
        case locked, armed
    }

    /// The element the user is looking at.
    public var lock: Rect?
    public var lockPhase: LockPhase = .locked
    /// Two close candidates: both outlined faintly, nothing clickable.
    public var uncertain: [Rect] = []
    /// Small gaze dot, shown when nothing is locked.
    public var gazeDot: Point?
    /// Scroll-dwell progress bar: the area and 0...1 progress; `towardTop` for the up zone.
    public var scrollProgress: (frame: Rect, progress: Double, towardTop: Bool)?
    /// "Where was I" line highlight.
    public var lineMarker: Rect?
    /// Focus-switch outline.
    public var windowFlash: Rect?
    /// Increments on every click (drives the press animation).
    public var clickCount = 0

    public init() {}

    public static func == (lhs: OverlayState, rhs: OverlayState) -> Bool {
        lhs.lock == rhs.lock && lhs.lockPhase == rhs.lockPhase && lhs.uncertain == rhs.uncertain
            && lhs.gazeDot == rhs.gazeDot && lhs.lineMarker == rhs.lineMarker && lhs.windowFlash == rhs.windowFlash
            && lhs.clickCount == rhs.clickCount && lhs.scrollProgress?.frame == rhs.scrollProgress?.frame
            && lhs.scrollProgress?.progress == rhs.scrollProgress?.progress
    }
}
