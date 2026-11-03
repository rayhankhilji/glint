import Carbon.HIToolbox

/// A system-wide shortcut (⌃⌥S by default) via Carbon's hot-key API: needs no permission and never sees other
/// keystrokes (G-SEC-02).
@MainActor
public final class HotKey {
    private static var action: (@MainActor () -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    public init(
        keyCode: UInt32 = UInt32(kVK_ANSI_S),
        modifiers: UInt32 = UInt32(controlKey | optionKey),
        action: @escaping @MainActor () -> Void
    ) {
        HotKey.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            MainActor.assumeIsolated { HotKey.action?() }
            return noErr
        }, 1, &spec, nil, &handlerRef)
        let id = EventHotKeyID(signature: OSType(0x5341_4343), id: 1)
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    /// Display string for the default shortcut.
    public static let defaultDisplay = "⌃⌥S"
}
