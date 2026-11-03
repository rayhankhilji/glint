import AppKit
import SaccadeCore

/// Windows on screen (ARCHITECTURE §5.1 WindowServicing). Reads only ids, owners and bounds, never titles.
@MainActor
public enum WindowService {
    /// The front-most normal window containing `point` (global top-left coordinates), excluding Saccade's own.
    public static func window(at point: Point) -> WindowInfo? {
        windows().first { $0.frame.contains(point) }
    }

    /// The front-most window of the frontmost app.
    public static func focusedWindowID() -> Int? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
        return windows().first { $0.pid == pid }?.id
    }

    /// Normal (layer 0) on-screen windows, front to back.
    static func windows() -> [WindowInfo] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] else { return [] }
        let me = ProcessInfo.processInfo.processIdentifier
        return list.compactMap { info in
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  let pid = info[kCGWindowOwnerPID as String] as? Int32, pid != me,
                  let number = info[kCGWindowNumber as String] as? Int,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary)
            else { return nil }
            return WindowInfo(
                id: number,
                pid: pid,
                frame: Rect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
            )
        }
    }
}

/// The frontmost app (for per-app rules).
@MainActor
public enum FrontmostApp {
    public static func bundleID() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}

/// Physical mouse and trackpad activity (ARCHITECTURE §5.1 InputMonitoring). Keystroke contents are never read
/// (G-SEC-02): typing is detected only as "seconds since the last key press".
@MainActor
public final class InputMonitor {
    public private(set) var lastPointerMove: Date = .distantPast
    public private(set) var lastScroll: Date = .distantPast
    public private(set) var mouseButtonDown = false
    /// Called with the location of every physical left click (global top-left coordinates): silent learning (F-04).
    public var onPhysicalClick: @MainActor (Point) -> Void = { _ in }
    private var monitor: Any?

    public init() {}

    public func start() {
        guard monitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [
            .mouseMoved,
            .leftMouseDragged,
            .scrollWheel,
            .leftMouseDown,
            .leftMouseUp,
            .rightMouseDown,
            .rightMouseUp,
        ]
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { event in
            let synthetic = event.cgEvent?.getIntegerValueField(.eventSourceUserData) == ActuationService.eventTag
            let type = event.type
            let location = NSEvent.mouseLocation
            MainActor.assumeIsolated {
                self.handle(type: type, location: location, synthetic: synthetic)
            }
        }
    }

    public func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    /// Seconds since any key was pressed, without seeing which key.
    public var secondsSinceKeyDown: TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
    }

    private func handle(type: NSEvent.EventType, location: NSPoint, synthetic: Bool) {
        guard !synthetic else { return }
        switch type {
        case .mouseMoved, .leftMouseDragged: lastPointerMove = Date()
        case .scrollWheel: lastScroll = Date()
        case .leftMouseDown:
            mouseButtonDown = true
            onPhysicalClick(Self.globalTopLeft(location))
        case .rightMouseDown: mouseButtonDown = true
        case .leftMouseUp, .rightMouseUp: mouseButtonDown = false
        default: break
        }
    }

    /// AppKit's bottom-left screen coordinates → global top-left (primary display) coordinates.
    static func globalTopLeft(_ p: NSPoint) -> Point {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return Point(x: Double(p.x), y: Double(primaryHeight - p.y))
    }
}
