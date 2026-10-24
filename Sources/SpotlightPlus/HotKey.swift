import AppKit
import Carbon.HIToolbox

/// A global keyboard shortcut (key + modifiers), persisted in UserDefaults.
struct Shortcut: Equatable {
    var keyCode: UInt32
    var modifiers: NSEvent.ModifierFlags
    var keyName: String

    static let `default` = Shortcut(keyCode: UInt32(kVK_Space), modifiers: [.option], keyName: "Space")

    static let functionKeys: [Int: String] = [
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17",
        kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    ]

    var carbonModifiers: UInt32 {
        var m: UInt32 = 0
        if modifiers.contains(.command) { m |= UInt32(cmdKey) }
        if modifiers.contains(.option) { m |= UInt32(optionKey) }
        if modifiers.contains(.control) { m |= UInt32(controlKey) }
        if modifiers.contains(.shift) { m |= UInt32(shiftKey) }
        return m
    }

    var displayString: String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option) { s += "⌥" }
        if modifiers.contains(.shift) { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + keyName
    }

    static func keyName(for event: NSEvent) -> String {
        let code = Int(event.keyCode)
        if let f = functionKeys[code] { return f }
        switch code {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_Home: return "↖"
        case kVK_End: return "↘"
        default:
            let chars = event.charactersIgnoringModifiers ?? "?"
            return chars.isEmpty ? "?" : chars.uppercased()
        }
    }

    // Persistence
    private static let codeKey = "hotkeyCode", modsKey = "hotkeyModifiers", nameKey = "hotkeyName"

    static func load() -> Shortcut {
        let d = UserDefaults.standard
        guard d.object(forKey: codeKey) != nil, let name = d.string(forKey: nameKey) else { return .default }
        return Shortcut(keyCode: UInt32(d.integer(forKey: codeKey)),
                        modifiers: NSEvent.ModifierFlags(rawValue: UInt(d.integer(forKey: modsKey))),
                        keyName: name)
    }

    func save() {
        let d = UserDefaults.standard
        d.set(Int(keyCode), forKey: Self.codeKey)
        d.set(Int(modifiers.rawValue), forKey: Self.modsKey)
        d.set(keyName, forKey: Self.nameKey)
    }
}

/// Registers one system-wide hotkey through Carbon (no Accessibility permission needed).
final class HotKeyManager {
    static let shared = HotKeyManager()
    var onPress: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// Returns false if the combination couldn't be registered (e.g. taken by another app).
    @discardableResult
    func register(_ shortcut: Shortcut) -> Bool {
        unregister()
        installHandlerIfNeeded()
        let id = EventHotKeyID(signature: OSType(0x5354_4D4E), id: 1) // 'STMN'
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, id,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        return status == noErr
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        hotKeyRef = nil
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKeyManager.shared.onPress?() }
            return noErr
        }, 1, &spec, nil, &handlerRef)
    }
}

final class ShortcutStore: ObservableObject {
    static let shared = ShortcutStore()
    @Published private(set) var shortcut = Shortcut.load()
    @Published private(set) var conflict = false

    func update(_ s: Shortcut) {
        shortcut = s
        s.save()
        registerCurrent()
    }

    func registerCurrent() {
        conflict = !HotKeyManager.shared.register(shortcut)
    }
}
