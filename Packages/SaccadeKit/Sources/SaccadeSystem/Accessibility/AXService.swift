import AppKit
import ApplicationServices
import SaccadeCore
import SaccadePlatform

/// Elements near a gaze point, read from the Accessibility tree.
public struct AXSnapshot: Sendable, Equatable {
    public var candidates: [TargetCandidate] = []
    public var scrollArea: ScrollAreaInfo?
    public init() {}
}

/// Reads the Accessibility tree around the gaze and performs AX actions (ARCHITECTURE §5.1 AXServicing).
/// All AX calls run on one serial queue with a 50 ms messaging timeout, so a slow app can't stall the UI.
/// Text values are never read: only roles, frames, actions and scroll positions (G-SEC-03).
public final class AXService: @unchecked Sendable {
    // @unchecked: `registry`, `nextID` and `manualAccessibility` are touched only on `queue`.
    private let queue = DispatchQueue(label: "app.saccade.ax", qos: .userInteractive)
    private let systemWide = AXUIElementCreateSystemWide()
    private var registry: [Int: AXUIElement] = [:]
    private var nextID = 1
    private var manualAccessibility: Set<pid_t> = []

    public init() {
        AXUIElementSetMessagingTimeout(systemWide, 0.05)
    }

    /// Whether Saccade may use Accessibility. With `prompt`, macOS shows its permission dialog.
    public static func isTrusted(prompt: Bool = false) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    /// Actionable elements around `point` (global top-left coordinates), sampled on a ring of `radius` points.
    public func snapshot(around point: Point, radius: Double) async -> AXSnapshot {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: self.collect(around: point, radius: radius)) }
        }
    }

    /// Performs an AX action on a candidate from the latest snapshots. Returns false if it isn't supported.
    public func perform(_ action: String, on id: Int) async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async {
                guard let element = self.registry[id] else { return continuation.resume(returning: false) }
                continuation.resume(returning: AXUIElementPerformAction(element, action as CFString) == .success)
            }
        }
    }

    // MARK: Collection (on `queue`)

    private static let actionableRoles: [String: TargetCandidate.Kind] = [
        kAXButtonRole: .button, "AXLink": .link, kAXMenuItemRole: .menuItem, kAXMenuBarItemRole: .menuItem,
        kAXCheckBoxRole: .checkbox, kAXRadioButtonRole: .tab, kAXPopUpButtonRole: .popUp, kAXMenuButtonRole: .popUp,
        kAXTextFieldRole: .textField, kAXTextAreaRole: .textField, kAXComboBoxRole: .popUp,
        kAXDisclosureTriangleRole: .button, kAXCellRole: .cell, kAXImageRole: .other, kAXStaticTextRole: .other,
    ]

    private func collect(around p: Point, radius: Double) -> AXSnapshot {
        if registry.count > 600 {
            registry.removeAll()
        }
        var snapshot = AXSnapshot()
        var seen: [AXUIElement] = []
        let r = min(max(radius, 12), 90)
        var probes = [p]
        for i in 0 ..< 8 {
            let a = Double(i) / 8 * 2 * .pi
            probes.append(Point(x: p.x + cos(a) * r, y: p.y + sin(a) * r))
        }
        for (index, probe) in probes.enumerated() {
            var hit: AXUIElement?
            guard AXUIElementCopyElementAtPosition(systemWide, Float(probe.x), Float(probe.y), &hit) == .success,
                  let element = hit else { continue }
            if index == 0 {
                enableWebAccessibility(for: element)
                snapshot.scrollArea = scrollArea(containing: element)
            }
            guard let target = actionableAncestor(of: element),
                  !seen.contains(where: { CFEqual($0, target) }) else { continue }
            seen.append(target)
            if let candidate = makeCandidate(target) {
                snapshot.candidates.append(candidate)
            }
        }
        return snapshot
    }

    /// Walks up to 4 ancestors to the nearest element a user would click.
    private func actionableAncestor(of element: AXUIElement) -> AXUIElement? {
        var current: AXUIElement? = element
        for _ in 0 ..< 5 {
            guard let el = current else { return nil }
            if isActionable(el) {
                return el
            }
            current = attribute(el, kAXParentAttribute) as AXUIElement?
        }
        return nil
    }

    private func isActionable(_ element: AXUIElement) -> Bool {
        guard let role: String = attribute(element, kAXRoleAttribute),
              Self.actionableRoles[role] != nil else { return false }
        if role == kAXStaticTextRole || role == kAXImageRole || role == kAXCellRole {
            return actions(of: element).contains(kAXPressAction)
        }
        return true
    }

    private func makeCandidate(_ element: AXUIElement) -> TargetCandidate? {
        let subrole: String? = attribute(element, kAXSubroleAttribute)
        guard subrole != kAXSecureTextFieldSubrole, // never highlight password fields (F-05.AC5)
              let role: String = attribute(element, kAXRoleAttribute),
              let frame = frame(of: element) else { return nil }
        let enabled: Bool = attribute(element, kAXEnabledAttribute) ?? true
        guard enabled else { return nil }
        let names = actions(of: element)
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        let id = nextID
        nextID += 1
        registry[id] = element
        return TargetCandidate(
            id: id, frame: frame, kind: Self.actionableRoles[role] ?? .other,
            canPress: names.contains(kAXPressAction) || role == kAXTextFieldRole || role == kAXTextAreaRole,
            canShowMenu: names.contains(kAXShowMenuAction), pid: pid
        )
    }

    private func scrollArea(containing element: AXUIElement) -> ScrollAreaInfo? {
        var current: AXUIElement? = element
        for _ in 0 ..< 12 {
            guard let el = current else { return nil }
            let role: String? = attribute(el, kAXRoleAttribute)
            if role == kAXScrollAreaRole, let frame = frame(of: el) {
                var info = ScrollAreaInfo(frame: frame)
                if let bar: AXUIElement = attribute(el, kAXVerticalScrollBarAttribute),
                   let value: Double = attribute(bar, kAXValueAttribute) {
                    info.canScrollUp = value > 0.001
                    info.canScrollDown = value < 0.999
                }
                return info
            }
            current = attribute(el, kAXParentAttribute) as AXUIElement?
        }
        return nil
    }

    /// Chromium and Electron apps only build their web accessibility tree when asked (F-05.AC6).
    private func enableWebAccessibility(for element: AXUIElement) {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success, !manualAccessibility.contains(pid) else { return }
        manualAccessibility.insert(pid)
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }

    // MARK: AX helpers

    private func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let value else { return nil }
        if T.self == AXUIElement.self {
            guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
            // CF bridging; the type was checked above.
            return (value as! AXUIElement) as? T // swiftlint:disable:this force_cast
        }
        if T.self == Double.self, let number = value as? NSNumber {
            return number.doubleValue as? T
        }
        if T.self == Bool.self, let number = value as? NSNumber {
            return number.boolValue as? T
        }
        return value as? T
    }

    private func actions(of element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success, let list = names as? [String] else { return [] }
        return list
    }

    private func frame(of element: AXUIElement) -> Rect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let positionRef, let sizeRef,
              CFGetTypeID(positionRef) == AXValueGetTypeID(), CFGetTypeID(sizeRef) == AXValueGetTypeID()
        else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        // CF bridging; types were checked above.
        // swiftlint:disable:next force_cast
        AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
        // swiftlint:disable:next force_cast
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        guard size.width > 0, size.height > 0 else { return nil }
        return Rect(
            x: Double(position.x),
            y: Double(position.y),
            width: Double(size.width),
            height: Double(size.height)
        )
    }
}
