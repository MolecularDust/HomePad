import AppKit

/// Opens the panel when a modifier key (⌃, ⌥ or ⌘) is tapped twice on its own.
/// Watching keys in other apps needs the Accessibility permission, unlike the Carbon hotkey.
final class DoubleTapMonitor {
    static let shared = DoubleTapMonitor()

    enum Key: String, CaseIterable, Identifiable {
        case off, control, option, command
        var id: String { rawValue }
        var title: String {
            switch self {
            case .off: return L("Off")
            case .control: return L("Control ⌃")
            case .option: return L("Option ⌥")
            case .command: return L("Command ⌘")
            }
        }
        var flag: NSEvent.ModifierFlags? {
            switch self {
            case .off: return nil
            case .control: return .control
            case .option: return .option
            case .command: return .command
            }
        }
    }

    static let defaultsKey = "doubleTapKey"
    private let window: TimeInterval = 0.3        // max time a single tap may take
    private let gap: TimeInterval = 0.4           // max time between the two taps

    private var monitors: [Any] = []
    private var pressedAt: TimeInterval?
    private var lastTapAt: TimeInterval = 0

    static var current: Key {
        Key(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .off
    }

    /// Call at launch and whenever the setting changes.
    /// `ask`: the user just chose a key, so Accessibility may be asked for. At launch it isn't: macOS's "would like
    /// to control this Mac" prompt would appear out of nowhere, before the Setup Guide has explained anything.
    func apply(ask: Bool = true) {
        for m in monitors { NSEvent.removeMonitor(m) }
        monitors = []
        pressedAt = nil
        lastTapAt = 0
        guard Self.current != .off else { return }
        if ask, !Permissions.accessibility { Permissions.requestAccessibility() }

        let handler: (NSEvent) -> Void = { [weak self] event in self?.handle(event) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown], handler: handler) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown], handler: { handler($0); return $0 }) {
            monitors.append(m)
        }
    }

    private func handle(_ event: NSEvent) {
        guard let target = Self.current.flag else { return }
        // Any ordinary key in between cancels the sequence (⌘C, ⌥-letter and so on).
        if event.type == .keyDown { pressedAt = nil; lastTapAt = 0; return }

        let flags = event.modifierFlags.intersection([.control, .option, .command, .shift])
        let now = ProcessInfo.processInfo.systemUptime
        if flags == target {
            pressedAt = now
        } else if flags.isEmpty, let down = pressedAt {
            pressedAt = nil
            guard now - down < window else { lastTapAt = 0; return }
            if now - lastTapAt < gap {
                lastTapAt = 0
                DispatchQueue.main.async { PanelController.shared.toggle() }
            } else {
                lastTapAt = now
            }
        } else {
            pressedAt = nil
            lastTapAt = 0
        }
    }
}

/// One-time copies of settings saved under the app's earlier names: SpotlightPlus, and before that Start Menu.
enum LegacyMigration {
    static func run() {
        fromSpotlightPlus()
        fromStartMenu()
    }

    /// Everything (categories, layout, shortcut, window size ...) carries over, except that the setup guide shows once
    /// more: macOS ties permissions to the app's id, so they have to be allowed again for the new one.
    private static func fromSpotlightPlus() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "migratedFromSpotlightPlus") else { return }
        defaults.set(true, forKey: "migratedFromSpotlightPlus")
        guard let old = defaults.persistentDomain(forName: "local.mike.SpotlightPlus") else { return }
        for (key, value) in old where key != "onboardingCompleted" && defaults.object(forKey: key) == nil {
            defaults.set(value, forKey: key)
        }
    }

    private static func fromStartMenu() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "migratedFromStartMenu") else { return }
        defaults.set(true, forKey: "migratedFromStartMenu")
        guard let old = UserDefaults(suiteName: "local.mike.StartMenu") else { return }
        for key in ["pinnedPaths", "columns", "showRunning", "hotkeyCode", "hotkeyModifiers", "hotkeyName"]
        where defaults.object(forKey: key) == nil {
            if let value = old.object(forKey: key) { defaults.set(value, forKey: key) }
        }
    }
}
