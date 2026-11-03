import Foundation
import SaccadeCore

// What the runtime needs from the system, as small protocols (ports). The app target adapts the macOS services
// (AX, CGEvent, window list, input monitor) to these, so every decision path is testable with fakes.

/// Finds actionable elements and the scroll area near a point (Accessibility).
public protocol TargetProviding: Sendable {
    func snapshot(around point: Point, radius: Double) async
        -> (candidates: [TargetCandidate], scrollArea: ScrollAreaInfo?)
}

/// Carries out intent actions (AX actions, clicks, scrolling, focus).
public protocol ActionPerforming: Sendable {
    func execute(_ action: IntentAction) async
}

/// Live system state the intent engine reads every frame.
@MainActor
public protocol SystemStateReading: AnyObject {
    func window(at point: Point) -> WindowInfo?
    func focusedWindowID() -> Int?
    func frontmostBundleID() -> String?
    var secondsSinceKeyDown: TimeInterval { get }
    var secondsSincePointerMove: TimeInterval { get }
    var secondsSinceManualScroll: TimeInterval { get }
    var mouseButtonDown: Bool { get }
}
