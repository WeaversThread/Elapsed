import AppKit
import Carbon.HIToolbox

/// System-wide shortcuts through Carbon's RegisterEventHotKey, which needs no Accessibility permission.
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    var onAction: ((HotkeyAction) -> Void)?

    private var registered: [EventHotKeyRef] = []
    private var current: [String: Hotkey] = [:]
    private var handler: EventHandlerRef?
    private var isSuspended = false

    nonisolated private static let signature: OSType = 0x454C_5053  // 'ELPS'

    func register(_ hotkeys: [String: Hotkey]) {
        current = hotkeys
        apply()
    }

    /// Off while a shortcut is being recorded, so the old combo doesn't fire instead.
    func suspend() {
        isSuspended = true
        apply()
    }

    func resume() {
        isSuspended = false
        apply()
    }

    private func apply() {
        registered.forEach { UnregisterEventHotKey($0) }
        registered = []
        guard !isSuspended, !current.isEmpty else { return }
        installHandler()

        for (index, action) in HotkeyAction.allCases.enumerated() {
            guard let key = current[action.rawValue] else { continue }
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: UInt32(index))
            if RegisterEventHotKey(key.keyCode, key.modifiers, id, GetEventDispatcherTarget(), 0, &ref) == noErr,
               let ref {
                registered.append(ref)
            }
        }
    }

    private func installHandler() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ in
            var id = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &id
            )
            guard status == noErr, id.signature == HotkeyManager.signature else {
                return OSStatus(eventNotHandledErr)
            }
            let index = Int(id.id)
            // Carbon delivers hot keys on the main thread.
            MainActor.assumeIsolated {
                HotkeyManager.shared.fire(index)
            }
            return noErr
        }, 1, &spec, nil, &handler)
    }

    private func fire(_ index: Int) {
        guard HotkeyAction.allCases.indices.contains(index) else { return }
        onAction?(HotkeyAction.allCases[index])
    }

    // MARK: - Display

    static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods = 0
        if flags.contains(.command) { mods |= cmdKey }
        if flags.contains(.option) { mods |= optionKey }
        if flags.contains(.control) { mods |= controlKey }
        if flags.contains(.shift) { mods |= shiftKey }
        return UInt32(mods)
    }

    static func symbols(_ flags: NSEvent.ModifierFlags) -> String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        return s
    }

    static let functionKeys: [Int: String] = [
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12", kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15",
        kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    ]

    static func keyName(_ event: NSEvent) -> String {
        let code = Int(event.keyCode)
        if let f = functionKeys[code] { return f }
        switch code {
        case kVK_Space:      return "Space"
        case kVK_Return:     return "↩"
        case kVK_Tab:        return "⇥"
        case kVK_LeftArrow:  return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow:    return "↑"
        case kVK_DownArrow:  return "↓"
        case kVK_Home:       return "↖"
        case kVK_End:        return "↘"
        case kVK_PageUp:     return "⇞"
        case kVK_PageDown:   return "⇟"
        default:
            return event.charactersIgnoringModifiers?.uppercased() ?? "?"
        }
    }
}
