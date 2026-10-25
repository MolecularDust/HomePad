import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?

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
        DoubleTapMonitor.shared.apply()

        setUpStatusItem()
        if !Onboarding.completed { Onboarding.show() }
    }

    // MARK: Menu bar icon

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "square.grid.3x3.fill",
                                           accessibilityDescription: "SpotlightPlus")
        let menu = NSMenu()
        menu.addItem(withTitle: "Open SpotlightPlus", action: #selector(openPanel), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Setup Guide…", action: #selector(openSetupGuide), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit SpotlightPlus", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
        statusItem.isVisible = UserDefaults.standard.object(forKey: "showMenuBarIcon") as? Bool ?? true
    }

    func setStatusItemVisible(_ visible: Bool) { statusItem.isVisible = visible }

    /// Launching the app again opens the panel, so it can't get lost when the menu-bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        PanelController.shared.show()
        return true
    }

    @objc private func openPanel() { PanelController.shared.show() }
    @objc private func openSetupGuide() { Onboarding.show() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc func openSettings() {
        PanelController.shared.hide(restoreFocus: false)
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView())
            host.sizingOptions = []           // the window is sized below, not by the content
            let window = NSWindow(contentViewController: host)
            window.title = "SpotlightPlus Settings"
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
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
                PermissionStatus.shared.watch(false)
            }
            settingsWindow = window
        }
        if settingsWindow?.isVisible == false { PermissionStatus.shared.watch(true) }
        settingsWindow?.center()
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
