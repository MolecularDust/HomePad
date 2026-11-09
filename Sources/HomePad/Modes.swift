import AppKit

/// How HomePad sits on the Mac (Settings → Mode):
///
/// - **Standalone**: a floating panel, opened by the shortcut, double-tap, hot corners or the menu-bar icon.
/// - **HomePad + Dock**: like the Windows Start menu, with the Dock as the taskbar. The Dock is shown (wherever you
///   put it) with HomePad kept in it, and the panel opens right by HomePad's Dock icon (DockIcon).
/// - **Taskbar**: like Windows. HomePad's own taskbar along the bottom of the main screen, with a Start button and the
///   running apps (which then leave the panel's Running section). The Dock is hidden meanwhile and comes back as it
///   was when you leave the mode. Optionally the panel opens only from the Start button.
enum HomePadMode: String, CaseIterable, Identifiable {
    case standalone, dock, taskbar
    var id: String { rawValue }

    static let key = "mode"
    /// Taskbar mode: the shortcut, double-tap and hot corners don't open HomePad, only the Start button (and the
    /// menu-bar icon) do.
    static let startButtonOnlyKey = "startButtonOnly"
    private static let dockWasHiddenKey = "dockHiddenBeforeTaskbar"

    static var current: HomePadMode {
        UserDefaults.standard.string(forKey: key).flatMap(HomePadMode.init(rawValue:)) ?? .standalone
    }

    /// Whether the shortcut, double-tap and hot corners may open the panel now.
    static var globalTriggersAllowed: Bool {
        !(current == .taskbar && UserDefaults.standard.bool(forKey: startButtonOnlyKey))
    }

    /// Settings' earlier switch "Open above the HomePad icon in the Dock" was this mode.
    static func migrate() {
        let d = UserDefaults.standard
        guard d.string(forKey: key) == nil else { return }
        if d.bool(forKey: "panelAboveDockIcon") { d.set(HomePadMode.dock.rawValue, forKey: key) }
        d.removeObject(forKey: "panelAboveDockIcon")
    }

    /// At launch: the taskbar comes back if it was on.
    static func applyAtLaunch() {
        if current == .taskbar { Taskbar.shared.show() }
    }

    /// Switches mode and does what the new one needs to the Dock and the taskbar.
    static func choose(_ new: HomePadMode) {
        let old = current
        guard new != old else { return }
        let d = UserDefaults.standard
        d.set(new.rawValue, forKey: key)

        if old == .taskbar {
            Taskbar.shared.hide()
            // The Dock comes back unless you had hidden it yourself before the taskbar.
            if new == .standalone, !d.bool(forKey: dockWasHiddenKey), DockControl.isHidden { DockControl.setHidden(false) }
        }
        switch new {
        case .standalone:
            break
        case .dock:
            DockControl.showWithHomePad()
        case .taskbar:
            d.set(DockControl.isHidden, forKey: dockWasHiddenKey)
            if !DockControl.isHidden { DockControl.setHidden(true) }
            Taskbar.shared.show()
        }
        PanelController.shared.hide(restoreFocus: false)
    }
}
