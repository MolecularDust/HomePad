import AppKit
import SwiftUI
import Combine
import ServiceManagement
import Carbon.HIToolbox

struct SettingsView: View {
    @ObservedObject private var shortcuts = ShortcutStore.shared
    @AppStorage("columns") private var columns = 8
    @AppStorage("showRunning") private var showRunning = true
    @AppStorage("rowHeight") private var rowHeight = RowMetrics.standard
    @AppStorage("iconSpacing") private var iconSpacing = TileMetrics.standardSpacing
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage(PanelController.rememberSizeKey) private var rememberSize = true
    @AppStorage(PanelController.rememberPositionKey) private var rememberPosition = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var dockHidden = DockControl.isHidden
    @AppStorage(DoubleTapMonitor.defaultsKey) private var doubleTap = DoubleTapMonitor.Key.off.rawValue
    @ObservedObject private var permissions = PermissionStatus.shared

    var body: some View {
        Form {
            Section("Shortcut") {
                HStack {
                    Text("Open HomePad")
                    Spacer()
                    ShortcutRecorder()
                }
                if shortcuts.isNone && doubleTap == DoubleTapMonitor.Key.off.rawValue {
                    Text("No shortcut is set. Open HomePad from the menu-bar icon, or choose a double-tap key below.")
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
                    permissions.refresh()
                }
                Text("Tap the key twice, quickly, on its own. This works alongside the shortcut above and needs the Accessibility permission.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Layout") {
                NumberSetting(title: "Icons per row", value: $columns, range: 4...10)
                NumberSetting(title: "Row height", value: $rowHeight, range: RowMetrics.range, step: 2, unit: "pt")
                NumberSetting(title: "Icon spacing", value: $iconSpacing, range: TileMetrics.spacingRange, step: 2, unit: "pt")
                Toggle("Show the Running section", isOn: $showRunning)
            }

            Section("Window") {
                Toggle("Remember window size", isOn: $rememberSize)
                Toggle("Remember window position", isOn: $rememberPosition)
                Text("For the main window, which you can resize by dragging its edges. The ↺ button in its corner goes back to the standard size, centred. The Add windows can be resized too, but always open at their standard size.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Items") {
                HStack {
                    Button("Add App…") { Launcher.chooseAppsToPin() }
                    Button("Add File or Folder…") { Launcher.chooseFilesToPin() }
                    Button("Add Category…") { Launcher.addCategory() }
                    Button("Re-import from Dock…") { confirmReimport() }
                }
            }

            Section("Permissions") {
                permissionRow("Accessibility", pane: "Privacy_Accessibility", granted: permissions.accessibility,
                              detail: "Jump to a specific window and double-tap a modifier key.") {
                    Permissions.requestAccessibility()
                }
                permissionRow("Screen Recording", pane: "Privacy_ScreenCapture", granted: permissions.screenRecording,
                              detail: "Window previews when you hover a running app.") {
                    Permissions.requestScreenRecording()
                    Permissions.openSettings("Privacy_ScreenCapture")
                }
                permissionRow("Full Disk Access", pane: "Privacy_AllFiles", granted: permissions.fullDiskAccess,
                              detail: "Find files in Documents, Desktop and Downloads. Add HomePad with + if it isn't listed, then relaunch it.") {
                    Permissions.openSettings("Privacy_AllFiles")
                }
                if !permissions.allGranted {
                    Text("Already switched on in System Settings but still red? Select HomePad there, remove it with −, then press Allow… again. This happens after an update changes the app's signature.")
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
                    Text("With the icon hidden, open HomePad with your shortcut or double-tap, or by launching the app again.")
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
        alert.informativeText = "This restores the shortcut (⌥Space), turns double-tap off, sets 8 icons per row and the standard row height and icon spacing, shows running apps, shows the menu-bar icon, shows the Dock again and turns off launch at login. Your apps and categories are kept."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        shortcuts.update(.default)
        doubleTap = DoubleTapMonitor.Key.off.rawValue
        columns = 8
        rowHeight = RowMetrics.standard
        iconSpacing = TileMetrics.standardSpacing
        rememberSize = true
        rememberPosition = false
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

/// A number you can type, or nudge with − and +. Not a Stepper: the system one repeats while its arrow is held, and
/// since every change re-lays out the panel it could miss the button coming up and keep counting down on its own.
/// These buttons take one step per click.
struct NumberSetting: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1
    var unit = ""
    @State private var text = ""
    @FocusState private var editing: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            Spacer()
            TextField(title, text: $text)
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(width: 48)
                .focused($editing)
                .onSubmit(commit)
                .onChange(of: editing) { focused in
                    if focused {
                        // Clicking in selects the number, so typing replaces it.
                        DispatchQueue.main.async { NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil) }
                    } else {
                        commit()                                    // leaving the field takes what was typed
                    }
                }
            if !unit.isEmpty { Text(unit).foregroundStyle(.secondary) }
            ControlGroup {
                Button { set(value - step) } label: { Image(systemName: "minus") }
                    .disabled(value <= range.lowerBound)
                Button { set(value + step) } label: { Image(systemName: "plus") }
                    .disabled(value >= range.upperBound)
            }
            .frame(width: 64)
        }
        .onAppear { text = String(value) }
        .onChange(of: value) { if !editing { text = String($0) } }
    }

    private func set(_ new: Int) {
        value = min(max(new, range.lowerBound), range.upperBound)
        text = String(value)
    }

    /// Takes the typed number, kept within the range; anything that isn't a number goes back to the current value.
    private func commit() {
        if let typed = Int(text.trimmingCharacters(in: .whitespaces)) { set(typed) } else { text = String(value) }
    }
}
