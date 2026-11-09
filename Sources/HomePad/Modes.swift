import AppKit

/// How HomePad sits on the Mac (Settings → Mode):
///
/// - **Standalone**: a floating panel, opened by the shortcut, double-tap, hot corners or the menu-bar icon. Choosing
///   it hides the Dock (Settings → Hide the Dock brings it back).
/// - **HomePad + Dock**: like the Windows Start menu, with the Dock as the taskbar. The Dock is shown (wherever you
///   put it) with HomePad kept in it, and the panel opens right by HomePad's Dock icon (DockIcon).
/// - **Taskbar**: like Windows. HomePad's own taskbar along the bottom of the main screen, with a Start button and the
///   running apps (which then leave the panel's Running section). The Dock stays under the taskbar meanwhile, so
///   windows fit above it (DockControl.reserveForTaskbar). Optionally the panel opens only from the Start button.
enum HomePadMode: String, CaseIterable, Identifiable {
    case standalone, dock, taskbar
    var id: String { rawValue }

    static let key = "mode"
    /// Taskbar mode: the shortcut, double-tap and hot corners don't open HomePad, only the Start button (and the
    /// menu-bar icon) do.
    static let startButtonOnlyKey = "startButtonOnly"

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
        guard current == .taskbar else { return }
        DockControl.reserveForTaskbar(height: Taskbar.height)      // in case the Dock was changed meanwhile
        Taskbar.shared.show()
    }

    /// Switches mode and does what the new one needs to the Dock and the taskbar: Standalone hides the Dock,
    /// HomePad + Dock shows it (each time, whatever it was before), Taskbar keeps it under the taskbar. `adjustingDock: false` leaves the Dock as it
    /// is (Reset to Defaults, which shows it itself).
    static func choose(_ new: HomePadMode, adjustingDock: Bool = true) {
        let old = current
        guard new != old else { return }
        UserDefaults.standard.set(new.rawValue, forKey: key)

        if old == .taskbar {
            Taskbar.shared.hide()
            DockControl.leaveTaskbar()
        }
        switch new {
        case .standalone:
            if adjustingDock { DockControl.setHidden(true) }
        case .dock:
            if adjustingDock { DockControl.showWithHomePad() }
        case .taskbar:
            DockControl.reserveForTaskbar(height: Taskbar.height)
            Taskbar.shared.show()
        }
        PanelController.shared.hide(restoreFocus: false)
    }
}
