import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox

struct SettingsView: View {
    @ObservedObject private var shortcuts = ShortcutStore.shared
    @AppStorage("columns") private var columns = 6
    @AppStorage("showRunning") private var showRunning = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var dockHidden = DockControl.isHidden

    var body: some View {
        Form {
            Section("Shortcut") {
                HStack {
                    Text("Open Start Menu")
                    Spacer()
                    ShortcutRecorder()
                }
                if shortcuts.conflict {
                    Text("That shortcut is already in use by another app. Pick a different one.")
                        .font(.caption).foregroundStyle(.red)
                }
                Text("To use ⌘Space, first turn off Spotlight's shortcut in System Settings → Keyboard → Keyboard Shortcuts → Spotlight.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Layout") {
                Stepper("Icons per row: \(columns)", value: $columns, in: 4...10)
                Toggle("Show running apps that aren't pinned", isOn: $showRunning)
            }

            Section("Pinned apps") {
                HStack {
                    Button("Add App…") { Launcher.chooseAppsToPin() }
                    Button("Re-import from Dock…") { confirmReimport() }
                }
            }

            Section("Dock") {
                Toggle("Hide the Dock", isOn: $dockHidden)
                    .onChange(of: dockHidden) { DockControl.setHidden($0) }
                Text("Turns on auto-hide with a very long delay, so the Dock never pops up. Cmd-Tab and Mission Control keep working.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("General") {
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
    }

    private func confirmReimport() {
        let alert = NSAlert()
        alert.messageText = "Replace pinned apps with the Dock's apps?"
        alert.informativeText = "Your current pinned list and its order will be replaced."
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            PinnedStore.shared.replaceWithDock()
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
                Text(recording ? "Press keys…" : store.shortcut.displayString)
                    .frame(minWidth: 110)
            }
            if !recording && store.shortcut != .default {
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
