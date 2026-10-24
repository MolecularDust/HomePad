import AppKit
import SwiftUI
import Combine
import ServiceManagement
import Carbon.HIToolbox

struct SettingsView: View {
    @ObservedObject private var shortcuts = ShortcutStore.shared
    @AppStorage("columns") private var columns = 6
    @AppStorage("showRunning") private var showRunning = true
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var dockHidden = DockControl.isHidden
    @AppStorage(DoubleTapMonitor.defaultsKey) private var doubleTap = DoubleTapMonitor.Key.off.rawValue
    @State private var hasAccessibility = Permissions.accessibility
    @State private var hasScreenRecording = Permissions.screenRecording

    var body: some View {
        Form {
            Section("Shortcut") {
                HStack {
                    Text("Open SpotlightPlus")
                    Spacer()
                    ShortcutRecorder()
                }
                if shortcuts.isNone && doubleTap == DoubleTapMonitor.Key.off.rawValue {
                    Text("No shortcut is set. Open SpotlightPlus from the menu-bar icon, or choose a double-tap key below.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let owner = shortcuts.conflict {
                    Text("That shortcut is already in use by \(owner.summary). Pick a different one.")
                        .font(.caption).foregroundStyle(.red)
                }
                Text("To use ⌘Space, first turn off Spotlight's shortcut in System Settings → Keyboard → Keyboard Shortcuts → Spotlight.")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("Or double-tap", selection: $doubleTap) {
                    ForEach(DoubleTapMonitor.Key.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .onChange(of: doubleTap) { _ in
                    DoubleTapMonitor.shared.apply()
                    hasAccessibility = Permissions.accessibility
                }
                Text("Tap the key twice, quickly, on its own. This works alongside the shortcut above and needs the Accessibility permission.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Layout") {
                Stepper("Icons per row: \(columns)", value: $columns, in: 4...10)
                Toggle("Show running apps that aren't pinned", isOn: $showRunning)
            }

            Section("Apps") {
                HStack {
                    Button("Add App…") { Launcher.chooseAppsToPin() }
                    Button("Add Category…") { Launcher.addCategory() }
                    Button("Re-import from Dock…") { confirmReimport() }
                }
            }

            Section("Permissions") {
                permissionRow("Accessibility", pane: "Privacy_Accessibility", granted: hasAccessibility,
                              detail: "Jump to a specific window and double-tap a modifier key.") {
                    Permissions.requestAccessibility()
                }
                permissionRow("Screen Recording", pane: "Privacy_ScreenCapture", granted: hasScreenRecording,
                              detail: "Window previews when you hover a running app.") {
                    Permissions.requestScreenRecording()
                    Permissions.openSettings("Privacy_ScreenCapture")
                }
                if !hasAccessibility || !hasScreenRecording {
                    Text("Already switched on in System Settings but still red? Select SpotlightPlus there, remove it with −, then press Allow… again. This happens after an update changes the app's signature.")
                    .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Dock") {
                Toggle("Hide the Dock", isOn: $dockHidden)
                    .onChange(of: dockHidden) { DockControl.setHidden($0) }
                Text("Turns on auto-hide with a very long delay, so the Dock never pops up. Cmd-Tab and Mission Control keep working.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Reset") {
                Button("Reset to Defaults…") { confirmReset() }
                Text("Puts the shortcut, double-tap, layout, menu-bar icon, Dock hiding and launch at login back to how they were at first. Your apps and categories are kept.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("General") {
                Toggle("Show menu-bar icon", isOn: $showMenuBarIcon)
                    .onChange(of: showMenuBarIcon) { AppDelegate.shared?.setStatusItemVisible($0) }
                if !showMenuBarIcon {
                    Text("With the icon hidden, open SpotlightPlus with your shortcut or double-tap, or by launching the app again.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { on in
                        do {
                            if on { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                        } catch {
                            NSAlert(error: error).runModal()
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            hasAccessibility = Permissions.accessibility
            hasScreenRecording = Permissions.screenRecording
        }
    }

    private func permissionRow(_ title: String, pane: String, granted: Bool, detail: String, request: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                PermissionButton(granted: granted, pane: pane, request: request)
            }
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func confirmReset() {
        let alert = NSAlert()
        alert.messageText = "Reset settings to their defaults?"
        alert.informativeText = "This restores the shortcut (⌥Space), turns double-tap off, sets 6 icons per row, shows running apps, shows the menu-bar icon, shows the Dock again and turns off launch at login. Your apps and categories are kept."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        shortcuts.update(.default)
        doubleTap = DoubleTapMonitor.Key.off.rawValue
        columns = 6
        showRunning = true
        showMenuBarIcon = true
        if dockHidden { dockHidden = false }
        if launchAtLogin { launchAtLogin = false }
    }

    private func confirmReimport() {
        let alert = NSAlert()
        alert.messageText = "Replace Essentials with the Dock's apps?"
        alert.informativeText = "Your current Essentials list and its order will be replaced. Other categories are kept."
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            CategoryStore.shared.replaceWithDock()
        }
    }
}

/// Click, then press the key combination you want.
struct ShortcutRecorder: View {
    @ObservedObject private var store = ShortcutStore.shared
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button(action: { recording ? stop() : start() }) {
                Text(recording ? "Press keys…" : (store.isNone ? "None" : store.shortcut.displayString))
                    .frame(minWidth: 110)
            }
            if !recording && !store.isNone {
                Button("None") { store.setNone() }
            }
            if !recording && (store.isNone || store.shortcut != .default) {
                Button("Reset") { store.update(.default) }
            }
        }
        .onDisappear { if recording { stop() } }
    }

    private func start() {
        recording = true
        HotKeyManager.shared.unregister()   // so pressing the old combo doesn't open the panel
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Int(event.keyCode) == kVK_Escape { stop(); return nil }
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            let isFunctionKey = Shortcut.functionKeys[Int(event.keyCode)] != nil
            // Require ⌘, ⌥ or ⌃ (Shift alone isn't enough) unless it's an F-key.
            guard !mods.subtracting(.shift).isEmpty || isFunctionKey else { NSSound.beep(); return nil }
            store.update(Shortcut(keyCode: UInt32(event.keyCode), modifiers: mods,
                                  keyName: Shortcut.keyName(for: event)))
            stop()
            return nil
        }
    }

    private func stop() {
        recording = false
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
        store.registerCurrent()
    }
}
