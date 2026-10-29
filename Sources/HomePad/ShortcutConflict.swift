import AppKit
import Carbon.HIToolbox

/// Works out who else may be using a global shortcut, and tells the user.
///
/// macOS accepts a second registration of the same key combination without an error, and gives apps no way to
/// ask who owns a shortcut. So a clash is only reported when it is shown: either it is one of macOS's own
/// shortcuts (read exactly from the system preferences), or a test press of the shortcut didn't reach this app.
/// A running app is named only as a "probably", after a test press has failed.
enum ShortcutConflict {
    enum Owner: Equatable {
        case system(name: String)
        case app(name: String, bundleURL: URL?)
        case unknown

        var summary: String {
            switch self {
            case .system(let name): return L("macOS (“\(name)”)")
            case .app(let name, _): return L("\(name) (probably)")
            case .unknown: return L("another app")
            }
        }
    }

    static let keyboardSettingsURL = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!
    private static let modifierMask: UInt = NSEvent.ModifierFlags([.shift, .control, .option, .command]).rawValue

    // MARK: Detection

    /// macOS shortcuts that are switched on (ids from the com.apple.symbolichotkeys preference).
    static func systemOwner(of shortcut: Shortcut) -> Owner? {
        let names: [Int: String] = [
            60: Mac("Select the previous input source"), 61: Mac("Select next source in Input menu"),
            64: Mac("Show Spotlight search"), 65: Mac("Show Finder search window"),
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

    /// Only used to put a name to a clash the test press has already proven: a running app that claims this
    /// shortcut by default. It is never reported on its own.
    static func appGuess(for shortcut: Shortcut) -> Owner? {
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

    /// Set once a press of this shortcut has really reached the app. It proves the shortcut works, so no
    /// warning is shown for it (until the user picks a different one).
    private static let confirmedKey = "confirmedShortcut"
    static func confirm(_ shortcut: Shortcut) { UserDefaults.standard.set(shortcut.displayString, forKey: confirmedKey) }
    static func forgetConfirmation() { UserDefaults.standard.removeObject(forKey: confirmedKey) }
    static func isConfirmed(_ shortcut: Shortcut) -> Bool {
        UserDefaults.standard.string(forKey: confirmedKey) == shortcut.displayString
    }

    static func forgetDismissal() { UserDefaults.standard.removeObject(forKey: dismissedKey) }
    static func isDismissed(_ shortcut: Shortcut) -> Bool {
        UserDefaults.standard.string(forKey: dismissedKey) == shortcut.displayString
    }

    /// Explains the clash and offers to help; Cancel leaves everything as it is and stops asking about this shortcut.
    static func report(_ shortcut: Shortcut, owner: Owner) {
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
            alert.messageText = L("\(keys) is already used by macOS")
            alert.informativeText = L("It's the shortcut for “\(name)”. To use \(keys) here, turn that shortcut off yourself in ⟦System Settings⟧ → ⟦Keyboard⟧ → ⟦Keyboard Shortcuts⟧. HomePad won't change your system settings.")
            button(L("Open ⟦Keyboard⟧ in ⟦System Settings⟧"), openKeyboardSettings)
        case .app(let name, let url):
            alert.messageText = L("\(keys) is probably used by \(name)")
            alert.informativeText = L("A test press of \(keys) didn't reach HomePad, so another app handles it first. \(name) is running and uses \(keys) by default, so it's the likely one, but macOS doesn't say which app owns a shortcut. To free it, change or turn off the shortcut in \(name)'s own settings, or choose a different shortcut here.")
            button(L("Open \(name)")) { if let url { NSWorkspace.shared.open(url) } }
        case .unknown:
            alert.messageText = L("\(keys) may already be in use")
            alert.informativeText = L("A test press of this shortcut didn't reach HomePad, so another app handles it first, but macOS doesn't say which one. Check the shortcut settings of any launcher or assistant apps you run, or choose a different shortcut here.")
        }
        button(L("Choose Another Shortcut")) { AppDelegate.shared?.openSettings() }
        alert.addButton(withTitle: L("Cancel"))

        let index = PanelController.shared.keepVisible { alert.runModal() }.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        if actions.indices.contains(index) {
            actions[index]()
        } else {
            UserDefaults.standard.set(keys, forKey: dismissedKey)
        }
    }
}
