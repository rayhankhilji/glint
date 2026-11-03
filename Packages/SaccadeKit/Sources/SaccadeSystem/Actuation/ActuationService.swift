import AppKit
import ApplicationServices
import SaccadeCore
import SaccadePlatform

/// The only place Saccade acts on other apps (G-SEC-04): AX press/show-menu/raise, mouse clicks as a fallback, and
/// pixel scroll-wheel events. Never keyboard events. Every posted event carries `eventTag` so Saccade's own input
/// monitor ignores it.
public final class ActuationService: @unchecked Sendable {
    // @unchecked: stateless apart from `ax`, which is itself thread-safe.
    public static let eventTag: Int64 = 0x5341_4343 // "SACC"
    private let ax: AXService
    private let scrollQueue = DispatchQueue(label: "app.saccade.scroll", qos: .userInteractive)

    public init(ax: AXService) {
        self.ax = ax
    }

    public func execute(_ action: IntentAction) async {
        switch action {
        case let .press(id, fallback):
            if await !ax.perform(kAXPressAction, on: id) {
                click(at: fallback, button: .left)
            }
        case let .showMenu(id, fallback):
            if await !ax.perform(kAXShowMenuAction, on: id) {
                click(at: fallback, button: .right)
            }
        case let .glide(delta, point, duration):
            glide(delta: delta, at: point, duration: duration)
        case let .focus(window):
            focus(window)
        }
    }

    /// A synthetic click at `point`; the cursor returns to where it was.
    private func click(at point: Point, button: CGMouseButton) {
        let target = CGPoint(x: point.x, y: point.y)
        let original = CGEvent(source: nil)?.location
        let (down, up): (CGEventType, CGEventType) = button == .left ? (.leftMouseDown, .leftMouseUp) : (
            .rightMouseDown,
            .rightMouseUp
        )
        for type in [down, up] {
            guard let event = CGEvent(
                mouseEventSource: nil,
                mouseType: type,
                mouseCursorPosition: target,
                mouseButton: button
            ) else { continue }
            event.setIntegerValueField(.eventSourceUserData, value: Self.eventTag)
            event.post(tap: .cghidEventTap)
        }
        if let original {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(40))
                CGWarpMouseCursorPosition(original)
                CGAssociateMouseAndMouseCursorPosition(1)
            }
        }
    }

    /// Smooth pixel scrolling at `point` (the window under the gaze), eased with the glide curve over `duration`.
    private func glide(delta: Double, at point: Point, duration: TimeInterval) {
        let steps = max(8, Int(duration * 120))
        let location = CGPoint(x: point.x, y: point.y)
        scrollQueue.async {
            var sent = 0.0
            for step in 1 ... steps {
                let target = delta * Self.glideCurve(Double(step) / Double(steps))
                let amount = (target - sent).rounded()
                sent += amount
                if amount != 0,
                   let event = CGEvent(
                       scrollWheelEvent2Source: nil,
                       units: .pixel,
                       wheelCount: 1,
                       wheel1: Int32(-amount),
                       wheel2: 0,
                       wheel3: 0
                   ) {
                    event.location = location
                    event.setIntegerValueField(.eventSourceUserData, value: Self.eventTag)
                    event.post(tap: .cghidEventTap)
                }
                Thread.sleep(forTimeInterval: duration / Double(steps))
            }
        }
    }

    /// cubic-bezier(0.22, 0.61, 0.36, 1) (DESIGN_SYSTEM `ease.glide`), solved for y at time x.
    static func glideCurve(_ x: Double) -> Double {
        let (x1, y1, x2, y2) = (0.22, 0.61, 0.36, 1.0)
        var t = x
        for _ in 0 ..< 8 {
            let cx = 3 * x1 * t * (1 - t) * (1 - t) + 3 * x2 * t * t * (1 - t) + t * t * t
            let dx = 3 * x1 * (1 - t) * (1 - t) + 6 * (x2 - x1) * t * (1 - t) + 3 * (1 - x2) * t * t
            guard abs(dx) > 1e-6 else { break }
            t = min(max(t - (cx - x) / dx, 0), 1)
        }
        return 3 * y1 * t * (1 - t) * (1 - t) + 3 * y2 * t * t * (1 - t) + t * t * t
    }

    /// Brings the window forward and makes its app active (F-08).
    private func focus(_ window: WindowInfo) {
        let app = AXUIElementCreateApplication(window.pid)
        var windowsRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
           let windows = windowsRef as? [AXUIElement] {
            let match = windows.first { element in
                var positionRef: CFTypeRef?
                guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) ==
                    .success,
                    let positionRef, CFGetTypeID(positionRef) == AXValueGetTypeID() else { return false }
                var position = CGPoint.zero
                // CF bridging; the type was checked above.
                // swiftlint:disable:next force_cast
                AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
                return abs(position.x - window.frame.minX) < 4 && abs(position.y - window.frame.minY) < 4
            }
            if let match {
                AXUIElementPerformAction(match, kAXRaiseAction as CFString)
            }
        }
        let pid = window.pid
        Task { @MainActor in
            NSRunningApplication(processIdentifier: pid)?.activate()
        }
    }
}
