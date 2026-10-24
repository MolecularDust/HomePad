import AppKit
import Carbon.HIToolbox

/// Works out who else may be using a global shortcut, and tells the user.
///
/// macOS accepts a second registration of the same key combination without an error, and gives apps no way to
/// ask who owns a shortcut. So this combines what can be known: macOS's own shortcuts (read exactly from the
/// system preferences) and well-known launcher apps that are running and use the shortcut by default (a best guess).
enum ShortcutConflict {
    enum Owner: Equatable {
        case system(name: String)
        case app(name: String, bundleURL: URL?)
        case unknown

        var summary: String {
            switch self {
            case .system(let name): return "macOS (“\(name)”)"
            case .app(let name, _): return "\(name) (probably)"
            case .unknown: return "another app"
            }
        }
    }

    static let keyboardSettingsURL = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!
    private static let modifierMask: UInt = NSEvent.ModifierFlags([.shift, .control, .option, .command]).rawValue

    // MARK: Detection

    /// nil means nothing known uses it.
    static func identify(_ shortcut: Shortcut) -> Owner? {
        systemOwner(of: shortcut) ?? appOwner(of: shortcut)
    }

    /// macOS shortcuts that are switched on (ids from the com.apple.symbolichotkeys preference).
    private static func systemOwner(of shortcut: Shortcut) -> Owner? {
        let names: [Int: String] = [
            60: "Select the previous input source", 61: "Select next source in Input menu",
            64: "Show Spotlight search", 65: "Show Finder search window",
        ]
        // Spotlight's two shortcuts are on by default and only appear in the preferences once changed.
        let defaults: [Int: (key: Int, mods: UInt)] = [
            64: (kVK_Space, NSEvent.ModifierFlags.command.rawValue),
            65: (kVK_Space, NSEvent.ModifierFlags([.command, .option]).rawValue),
        ]
        let table = CFPreferencesCopyAppValue("AppleSymbolicHotKeys" as CFString,
                                              "com.apple.symbolichotkeys" as CFString) as? [String: Any] ?? [:]
        let mine = shortcut.modifiers.rawValue & modifierMask
        for (id, name) in names {
            let entry = table[String(id)] as? [String: Any]
            if let enabled = entry?["enabled"] as? Bool, !enabled { continue }
            var key: Int?, mods: UInt?
            if let params = (entry?["value"] as? [String: Any])?["parameters"] as? [Int], params.count == 3 {
                key = params[1]; mods = UInt(params[2]) & modifierMask
            } else if entry == nil, let d = defaults[id] {
                key = d.key; mods = d.mods
            }
            if key == Int(shortcut.keyCode), mods == mine { return .system(name: name) }
        }
        return nil
    }

    /// Running apps that are known to claim this shortcut out of the box.
    private static func appOwner(of shortcut: Shortcut) -> Owner? {
        let option = NSEvent.ModifierFlags.option, command = NSEvent.ModifierFlags.command
        let known: [(app: String, key: Int, mods: NSEvent.ModifierFlags)] = [
            ("Gemini", kVK_Space, option), ("ChatGPT", kVK_Space, option),
            ("Raycast", kVK_Space, option), ("Raycast", kVK_Space, command),
            ("Alfred", kVK_Space, option), ("Alfred", kVK_Space, command),
            ("LaunchBar", kVK_Space, command),
        ]
        let me = ProcessInfo.processInfo.processIdentifier
        let mods = shortcut.modifiers.intersection([.shift, .control, .option, .command])
        for entry in known where entry.key == Int(shortcut.keyCode) && entry.mods == mods {
            if let app = NSWorkspace.shared.runningApplications.first(where: {
                $0.localizedName == entry.app && $0.processIdentifier != me
            }) {
                return .app(name: entry.app, bundleURL: app.bundleURL)
            }
        }
        return nil
    }

    // MARK: Telling the user

    private static let dismissedKey = "dismissedShortcutConflict"

    static func forgetDismissal() { UserDefaults.standard.removeObject(forKey: dismissedKey) }
    static func isDismissed(_ shortcut: Shortcut) -> Bool {
        UserDefaults.standard.string(forKey: dismissedKey) == shortcut.displayString
    }

    /// Explains the clash and offers to help; Cancel leaves everything as it is and stops asking about this shortcut.
    static func report(_ shortcut: Shortcut, owner: Owner) {
        PanelController.shared.hide(restoreFocus: false)
        activateSelf()

        let alert = NSAlert()
        alert.alertStyle = .warning
        let keys = shortcut.displayString
        var actions: [() -> Void] = []          // one per button, in order; Cancel has none
        func button(_ title: String, _ action: @escaping () -> Void) {
            alert.addButton(withTitle: title)
            actions.append(action)
        }
        let openKeyboardSettings: () -> Void = { NSWorkspace.shared.open(keyboardSettingsURL) }

        switch owner {
        case .system(let name):
            alert.messageText = "\(keys) is already used by macOS"
            alert.informativeText = "It's the shortcut for “\(name)”. To use \(keys) here, turn that shortcut off yourself in System Settings → Keyboard → Keyboard Shortcuts. SpotlightPlus won't change your system settings."
            button("Open Keyboard Settings", openKeyboardSettings)
        case .app(let name, let url):
            alert.messageText = "\(keys) is probably used by \(name)"
            alert.informativeText = "\(name) is running and uses \(keys) by default, so pressing it may open \(name) instead. macOS doesn't say which app owns a shortcut, so this is a best guess. To free it, change or turn off the shortcut in \(name)'s own settings, or choose a different shortcut here."
            button("Open \(name)") { if let url { NSWorkspace.shared.open(url) } }
        case .unknown:
            alert.messageText = "\(keys) may already be in use"
            alert.informativeText = "Another app seems to be using this shortcut, but macOS doesn't say which one. Check the shortcut settings of any launcher or assistant apps you run, or choose a different shortcut here."
        }
        button("Choose Another Shortcut") { AppDelegate.shared?.openSettings() }
        alert.addButton(withTitle: "Cancel")

        let index = alert.runModal().rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        if actions.indices.contains(index) {
            actions[index]()
        } else {
            UserDefaults.standard.set(keys, forKey: dismissedKey)
        }
    }
}
