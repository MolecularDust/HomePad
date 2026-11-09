import AppKit
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu?
    private var settingsWindow: NSWindow?
    /// Settings was opened from the panel (its gear): the panel stays behind it, and gets keyboard focus back when
    /// Settings closes.
    private var panelBehindSettings = false
    private static let settingsOriginKey = "settingsWindowOrigin"

    func applicationDidFinishLaunching(_ notification: Notification) {
        LegacyMigration.run()
        Localization.migrate()
        HomePadMode.migrate()
        #if DEBUG
        Snapshot.startIfAsked()
        if UserDefaults.standard.bool(forKey: "HomePadRunningOrderTest") { RunningOrder.selfTest(); exit(0) }
        #endif
        // Touch singletons so they start observing right away.
        _ = CategoryStore.shared
        _ = RunningApps.shared
        _ = PanelController.shared

        HotKeyManager.shared.onPress = {
            ShortcutStore.shared.confirmWorking()
            guard HomePadMode.globalTriggersAllowed else { return }
            PanelController.shared.toggle()
        }
        ShortcutStore.shared.registerCurrent(report: true)
        DoubleTapMonitor.shared.apply(ask: false)
        HotCornerMonitor.shared.apply()
        HomePadMode.applyAtLaunch()

        setUpStatusItem()
        PermissionStatus.shared.onGranted = { [weak self] restartComing in
            // Accessibility may be what just came on: start listening for the double tap again with it.
            DoubleTapMonitor.shared.apply(ask: false)
            DragInHelper.close()
            if restartComing {
                // System Settings is asking Quit & Reopen: HomePad stays in the background so the question keeps
                // focus. Quit & Reopen brings the guide back after the relaunch; with Later, it comes back once
                // System Settings closes.
                SystemSettingsWindow.whenClosed { self?.bringBack() }
            } else {
                SystemSettingsWindow.closeAfterGrant()
                self?.bringBack()
            }
        }
        // Back from a Quit & Reopen: the window you were in opens again, and System Settings closes.
        let reopening = Relaunch.windowToReopen()
        if reopening != nil { SystemSettingsWindow.closeAfterGrant() } else { SystemSettingsWindow.forget() }
        switch reopening {
        case "settings": openSettings()
        case "setupGuide": Onboarding.show()
        default:
            // The first time only, and only when something is missing: with every permission already on, the
            // guide has nothing to do.
            if !Onboarding.completed {
                if PermissionStatus.shared.allGranted { Onboarding.markCompleted() } else { Onboarding.show() }
            }
        }
    }

    /// A permission was just switched on in System Settings: HomePad comes back to the front, in the window that
    /// asked for it (the Setup Guide or Settings), or with its panel.
    private func bringBack() {
        if Onboarding.isOpen {
            Onboarding.show()
        } else if settingsWindow?.isVisible == true {
            activateSelf()
            settingsWindow?.makeKeyAndOrderFront(nil)
        } else if DockIcon.isOn, Date().timeIntervalSince(PanelController.shared.hiddenAt) < 0.3 {
            // A click on HomePad's Dock icon while the panel is open: the click took focus, which closed the panel
            // just before; it counts as "close", not "open again" (as for the menu-bar icon).
        } else {
            PanelController.shared.show()
        }
    }

    /// System Settings' "Quit & Reopen" (after Screen Recording or Full Disk Access is switched on) quits HomePad but
    /// didn't start it again, so HomePad relaunches itself when System Settings is what asked it to quit.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if Relaunch.quitAskedBySystemSettings() || (PermissionStatus.shared.expectsQuitAndReopen && Relaunch.quitAskedByAnotherApp()) {
            Relaunch.afterQuitting(reopening: Onboarding.isOpen ? "setupGuide" : (settingsWindow?.isVisible == true ? "settings" : nil))
        }
        return .terminateNow
    }

    // MARK: Menu bar icon

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "square.grid.3x3.fill",
                                           accessibilityDescription: "HomePad")
        let menu = NSMenu()
        menu.addItem(withTitle: L("Open HomePad"), action: #selector(openPanel), keyEquivalent: "").target = self
        // No ⌘, here: HomePad is never the app in front when this menu is open, so the shortcut went to that app
        // (Finder's settings, say), not to HomePad.
        menu.addItem(withTitle: L("Settings…"), action: #selector(openSettings), keyEquivalent: "").target = self
        menu.addItem(withTitle: L("Setup Guide…"), action: #selector(openSetupGuide), keyEquivalent: "").target = self
        let language = NSMenuItem(title: L("Language"), action: nil, keyEquivalent: "")
        language.submenu = Localization.menu()
        menu.addItem(language)
        menu.addItem(.separator())
        menu.addItem(withTitle: L("Uninstall HomePad…"), action: #selector(uninstall), keyEquivalent: "").target = self
        menu.addItem(withTitle: L("Quit HomePad"), action: #selector(quit), keyEquivalent: "q").target = self
        // A click opens (or closes) the panel; a right click or Control-click shows this menu. With `menu` set on
        // the status item, every click would show the menu, so it's shown by hand instead.
        statusMenu = menu
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        // On mouse down, as menu-bar icons respond, so the panel opens without waiting for the button to come up.
        statusItem.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
        statusItem.isVisible = UserDefaults.standard.object(forKey: "showMenuBarIcon") as? Bool ?? true
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseDown || event?.modifierFlags.contains(.control) == true {
            showStatusMenu()
        } else if Date().timeIntervalSince(PanelController.shared.hiddenAt) < 0.3 {
            // The panel was open and closed itself as this click took focus: leave it closed.
        } else {
            PanelController.shared.toggle()
        }
    }

    private func showStatusMenu() {
        guard let button = statusItem.button, let statusMenu else { return }
        // Set for the duration only: the system then places and highlights the menu as for any menu-bar icon.
        statusItem.menu = statusMenu
        button.performClick(nil)
        statusItem.menu = nil
    }

    func setStatusItemVisible(_ visible: Bool) { statusItem.isVisible = visible }
    var settingsWindowIsOpen: Bool { settingsWindow?.isVisible == true }

    /// Launching the app again opens the panel, so it can't get lost when the menu-bar icon is hidden. With the
    /// Setup Guide or Settings open, that window comes forward instead: the panel must not cover it.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        bringBack()
        return true
    }

    @objc private func openPanel() { PanelController.shared.show() }
    @objc private func openSetupGuide() { Onboarding.show() }
    @objc private func quit() { NSApp.terminate(nil) }

    /// Asks first, then does what only the running app can (brings the Dock back if HomePad hid it, turns off launch
    /// at login), starts uninstall.sh from the app's Resources and quits. The script waits for HomePad to quit, then
    /// takes back its permissions, erases its settings, moves the app to the Trash and says when it's done.
    @objc private func uninstall() {
        activateSelf()
        let alert = NSAlert()
        alert.messageText = L("Uninstall HomePad?")
        alert.informativeText = L("HomePad quits and goes to the ⟦Trash⟧. Its categories and settings are erased, the permissions you gave it are taken back, and the ⟦Dock⟧ comes back if HomePad was hiding it. Your apps and files aren't touched.")
        alert.addButton(withTitle: L("Uninstall"))
        alert.addButton(withTitle: L("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let bundled = Bundle.main.url(forResource: "uninstall", withExtension: "sh") else {
            let missing = NSAlert()
            missing.messageText = L("The uninstall script is missing from this copy of HomePad")
            missing.informativeText = L("Quit HomePad and drag it from ⟦Applications⟧ to the ⟦Trash⟧.")
            missing.runModal()
            return
        }
        // A copy outside the app: the app (and the script inside it) is about to go to the Trash.
        let script = FileManager.default.temporaryDirectory.appendingPathComponent("HomePad-uninstall.sh")
        try? FileManager.default.removeItem(at: script)
        guard (try? FileManager.default.copyItem(at: bundled, to: script)) != nil else { return }

        if DockControl.restoreTaskbarPrefs() || DockControl.isHidden { DockControl.showNow() }
        try? SMAppService.mainApp.unregister()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path, "--wait", String(ProcessInfo.processInfo.processIdentifier), "--notify",
                             "--text-done", L("HomePad has been uninstalled. It is in the ⟦Trash⟧, in case you want it back."),
                             "--text-password", L("HomePad needs your password to finish uninstalling."),
                             Bundle.main.bundlePath]
        guard (try? process.run()) != nil else { return }
        NSApp.terminate(nil)
    }

    @objc func openSettings() {
        if settingsWindow?.isVisible != true, PanelController.shared.isVisible {
            panelBehindSettings = true
            PanelController.shared.stayBehind(true)
        }
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView().localized())
            host.sizingOptions = []           // the window is sized below, not by the content
            let window = NSWindow(contentViewController: host)
            window.title = L("HomePad Settings")
            window.styleMask = [.titled, .closable, .resizable]
            // As tall as the settings need, but never taller than the screen: the form scrolls inside.
            let natural = NSHostingView(rootView: SettingsView().localized().fixedSize(horizontal: false, vertical: true)).fittingSize.height
            let available = (NSScreen.main?.visibleFrame.height ?? 800) - 110      // leaves room for the title bar
            window.setContentSize(NSSize(width: 480, height: min(natural, available)))
            window.contentMinSize = NSSize(width: 480, height: 300)
            window.contentMaxSize = NSSize(width: 480, height: CGFloat.greatestFiniteMagnitude)
            // An empty toolbar gives the full-height title bar regular Mac apps have.
            window.toolbar = NSToolbar(identifier: "SettingsWindow")
            window.toolbarStyle = .unified
            window.isReleasedWhenClosed = false
            // The window is kept when closed, so its view never goes away: the permission buttons are kept current
            // from here, only while it is open.
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
                PermissionStatus.shared.watch(false)
                guard let self, self.panelBehindSettings else { return }
                self.panelBehindSettings = false
                // After the window has gone, so the panel takes focus rather than the closing window keeping it.
                DispatchQueue.main.async { PanelController.shared.stayBehind(false) }
            }
            settingsWindow = window
            // Centered the first time; after that it stays where you put it. Only the position is restored: the
            // height is worked out above.
            if let saved = UserDefaults.standard.string(forKey: Self.settingsOriginKey) {
                window.setFrameOrigin(NSPointFromString(saved))
            } else {
                window.center()
            }
            NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main) { [weak window] _ in
                guard let window else { return }
                UserDefaults.standard.set(NSStringFromPoint(window.frame.origin), forKey: Self.settingsOriginKey)
            }
        }
        if settingsWindow?.isVisible == false { PermissionStatus.shared.watch(true) }
        activateSelf()
        settingsWindow?.makeKeyAndOrderFront(nil)
        // SwiftUI puts the cursor in the first text field (Icons per row) when the window opens; start with nothing
        // focused instead, so a stray key press can't change a setting.
        DispatchQueue.main.async { self.settingsWindow?.makeFirstResponder(nil) }
    }

    static var shared: AppDelegate? { NSApp.delegate as? AppDelegate }
}

/// Brings the app to the front. The polite form (`NSApp.activate()`, macOS 14 and later) is often declined when
/// another app is in front, which left the panel without keyboard focus; this form is not, and it's what
/// launcher-style apps use. It is only called in response to the user: the shortcut, a click, a menu item.
func activateSelf() {
    NSApp.activate(ignoringOtherApps: true)
}

/// Starting HomePad again after it quits, for System Settings' "Quit & Reopen".
enum Relaunch {
    private static let reopenKey = "reopenAfterRelaunch"
    private static let settingsApps: Set<String> = ["com.apple.systempreferences", "com.apple.Settings"]

    /// The process that sent the quit request being handled, if it came as an Apple event from another process.
    private static var quitSender: pid_t? {
        guard let event = NSAppleEventManager.shared().currentAppleEvent, event.eventClass == kCoreEventClass,
              event.eventID == kAEQuitApplication,
              let pid = event.attributeDescriptor(forKeyword: AEKeyword(keySenderPIDAttr))?.int32Value,
              pid != ProcessInfo.processInfo.processIdentifier else { return nil }
        return pid
    }

    static func quitAskedBySystemSettings() -> Bool {
        quitSender.flatMap { NSRunningApplication(processIdentifier: $0)?.bundleIdentifier }.map(settingsApps.contains) ?? false
    }

    /// Any other process (not only an app: macOS's privacy service may send it on System Settings' behalf).
    static func quitAskedByAnotherApp() -> Bool { quitSender != nil }

    /// Starts a tiny helper that waits for this process to end, then opens the app again; `window` is what to show.
    /// System Settings' Quit & Reopen sometimes starts HomePad itself. Then the helper does nothing, because `open` on
    /// a running app counts as clicking it again, which used to put the panel over the Setup Guide.
    static func afterQuitting(reopening window: String?) {
        UserDefaults.standard.set(window, forKey: reopenKey)
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        helper.arguments = ["-c", "while /bin/kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do /bin/sleep 0.2; done; /bin/sleep 1; /usr/bin/pgrep -x HomePad >/dev/null || /usr/bin/open \"$0\"",
                            Bundle.main.bundlePath]
        try? helper.run()
    }

    /// What to show after such a relaunch, once (nil normally).
    static func windowToReopen() -> String? {
        defer { UserDefaults.standard.removeObject(forKey: reopenKey) }
        return UserDefaults.standard.string(forKey: reopenKey)
    }
}
