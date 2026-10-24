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

        HotKeyManager.shared.onPress = { PanelController.shared.toggle() }
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
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            window.title = "SpotlightPlus Settings"
            window.styleMask = [.titled, .closable]
            // An empty toolbar gives the full-height title bar regular Mac apps have.
            window.toolbar = NSToolbar(identifier: "SettingsWindow")
            window.toolbarStyle = .unified
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.center()
        activateSelf()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    static var shared: AppDelegate? { NSApp.delegate as? AppDelegate }
}

func activateSelf() {
    if #available(macOS 14.0, *) {
        NSApp.activate()
    } else {
        NSApp.activate(ignoringOtherApps: true)
    }
}
