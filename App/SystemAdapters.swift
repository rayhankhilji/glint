import Foundation
import SaccadeCore
import SaccadeRuntime
import SaccadeSystem

// Adapts the macOS services in SaccadeSystem to the runtime's ports (ARCHITECTURE §3). Wiring only.

struct AccessibilityTargets: TargetProviding {
    let ax: AXService

    func snapshot(
        around point: Point,
        radius: Double
    ) async -> (candidates: [TargetCandidate], scrollArea: ScrollAreaInfo?) {
        let snapshot = await ax.snapshot(around: point, radius: radius)
        return (snapshot.candidates, snapshot.scrollArea)
    }
}

struct SystemActuator: ActionPerforming {
    let actuation: ActuationService

    func execute(_ action: IntentAction) async {
        await actuation.execute(action)
    }
}

@MainActor
final class LiveSystemState: SystemStateReading {
    private let input: InputMonitor

    init(input: InputMonitor) {
        self.input = input
    }

    func window(at point: Point) -> WindowInfo? {
        WindowService.window(at: point)
    }
    func focusedWindowID() -> Int? {
        WindowService.focusedWindowID()
    }
    func frontmostBundleID() -> String? {
        FrontmostApp.bundleID()
    }
    var secondsSinceKeyDown: TimeInterval { input.secondsSinceKeyDown }
    var secondsSincePointerMove: TimeInterval { Date().timeIntervalSince(input.lastPointerMove) }
    var secondsSinceManualScroll: TimeInterval { Date().timeIntervalSince(input.lastScroll) }
    var mouseButtonDown: Bool { input.mouseButtonDown }
}
