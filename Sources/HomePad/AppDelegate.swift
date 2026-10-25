import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    /// Settings was opened from the panel (its gear): the panel stays behind it, and gets keyboard focus back when
    /// Settings closes.
    private var panelBehindSettings = false
    private static let settingsOriginKey = "settingsWindowOrigin"

    func applicationDidFinishLaunching(_ notification: Notification) {
        LegacyMigration.run()
        // Touch singletons so they start observing right away.
        _ = CategoryStore.shared
        _ = RunningApps.shared
        _ = PanelController.shared

        HotKeyManager.shared.onPress = {
            ShortcutStore.shared.confirmWorking()
            PanelController.shared.toggle()
        }
        ShortcutStore.shared.registerCurrent(report: true)
        DoubleTapMonitor.shared.apply(ask: false)

        setUpStatusItem()
        PermissionStatus.shared.onGranted = { [weak self] restartComing in
            // Accessibility may be what just came on: start listening for the double tap again with it.
            DoubleTapMonitor.shared.apply(ask: false)
            // System Settings is about to offer Quit & Reopen: it stays until HomePad is back.
            if !restartComing { SystemSettingsWindow.closeIfOpenedByUs() }
            self?.bringBack()
        }
        // Back from a Quit & Reopen: the window you were in opens again, and System Settings closes if HomePad
        // opened it.
        let reopening = Relaunch.windowToReopen()
        if reopening != nil { SystemSettingsWindow.closeIfOpenedByUs() } else { SystemSettingsWindow.forget() }
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
        menu.addItem(withTitle: "Open HomePad", action: #selector(openPanel), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Setup Guide…", action: #selector(openSetupGuide), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit HomePad", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
        statusItem.isVisible = UserDefaults.standard.object(forKey: "showMenuBarIcon") as? Bool ?? true
    }

    func setStatusItemVisible(_ visible: Bool) { statusItem.isVisible = visible }

    /// Launching the app again opens the panel, so it can't get lost when the menu-bar icon is hidden. With the
    /// Setup Guide or Settings open, that window comes forward instead: the panel must not cover it.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        bringBack()
        return true
    }

    @objc private func openPanel() { PanelController.shared.show() }
    @objc private func openSetupGuide() { Onboarding.show() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc func openSettings() {
        if settingsWindow?.isVisible != true, PanelController.shared.isVisible {
            panelBehindSettings = true
            PanelController.shared.stayBehind(true)
        }
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView())
            host.sizingOptions = []           // the window is sized below, not by the content
            let window = NSWindow(contentViewController: host)
            window.title = "HomePad Settings"
            window.styleMask = [.titled, .closable, .resizable]
            // As tall as the settings need, but never taller than the screen: the form scrolls inside.
            let natural = NSHostingView(rootView: SettingsView().fixedSize(horizontal: false, vertical: true)).fittingSize.height
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
