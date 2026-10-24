import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Touch singletons so they start observing right away.
        _ = PinnedStore.shared
        _ = RunningApps.shared
        _ = PanelController.shared

        HotKeyManager.shared.onPress = { PanelController.shared.toggle() }
        ShortcutStore.shared.registerCurrent()

        setUpStatusItem()
    }

    // MARK: Menu bar icon

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "square.grid.3x3.fill",
                                           accessibilityDescription: "Start Menu")
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Start Menu", action: #selector(openPanel), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Start Menu", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
    }

    @objc private func openPanel() { PanelController.shared.show() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc func openSettings() {
        PanelController.shared.hide(restoreFocus: false)
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            window.title = "Start Menu Settings"
            window.styleMask = [.titled, .closable]
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
