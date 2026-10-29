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
    @AppStorage(HotCornerMonitor.defaultsKey) private var hotCorners = ""
    @AppStorage(MinimisedWindows.settingKey) private var hideMinimised = true
    @ObservedObject private var permissions = PermissionStatus.shared

    var body: some View {
        Form {
            Section("Shortcut") {
                HStack {
                    Text("Open HomePad")
                    Spacer()
                    ShortcutRecorder().fixedSize()
                }
                if shortcuts.isNone && doubleTap == DoubleTapMonitor.Key.off.rawValue {
                    Text("No shortcut is set. Open HomePad from the menu-bar icon, or choose a double-tap key below.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let owner = shortcuts.conflict {
                    Text("That shortcut is already in use by \(owner.summary). Pick a different one.")
                        .font(.caption).foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(L("To use ⌘Space, first turn off the ⟦Spotlight⟧ shortcut in ⟦System Settings⟧ → ⟦Keyboard⟧ → ⟦Keyboard Shortcuts⟧ → ⟦Spotlight⟧."))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Picker("Or double-tap", selection: $doubleTap) {
                    ForEach(DoubleTapMonitor.Key.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .onChange(of: doubleTap) { _ in
                    DoubleTapMonitor.shared.apply()
                    permissions.refresh()
                }
                Text(L("Tap the key twice, quickly, on its own. This works alongside the shortcut above and needs the ⟦Accessibility⟧ permission."))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HotCornerSetting()
            }

            Section("Layout") {
                NumberSetting(title: L("Icons per row"), value: $columns, range: 4...10)
                NumberSetting(title: L("Row height"), value: $rowHeight, range: RowMetrics.range, step: 2, unit: "pt")
                NumberSetting(title: L("Icon spacing"), value: $iconSpacing, range: TileMetrics.spacingRange, step: 2, unit: "pt")
                Toggle("Show the Running section", isOn: $showRunning)
                Toggle("Show minimized windows in Running", isOn: Binding(get: { !hideMinimised }, set: { hideMinimised = !$0 }))
                    .disabled(!showRunning)
                    .onChange(of: hideMinimised) { _ in MinimisedWindows.shared.refresh() }
                Text(L("Each minimized window gets a tile right after its app; click it to bring the window back. Needs ⟦Accessibility⟧, and ⟦Screen Recording⟧ for the pictures. Both can also be changed by right-clicking the Running section."))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Window") {
                Toggle("Remember window size", isOn: $rememberSize)
                Toggle("Remember window position", isOn: $rememberPosition)
                Text("For the main window, which you can resize by dragging its edges. The ↺ button in its corner goes back to the standard size, centred. The Add windows can be resized too, but always open at their standard size.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Items") {
                // One row when the names fit (English); two rows in languages with longer words.
                ViewThatFits(in: .horizontal) {
                    HStack { addApp; addFile; addCategory; reimport }
                    VStack(alignment: .leading) {
                        HStack { addApp; addFile }
                        HStack { addCategory; reimport }
                    }
                    VStack(alignment: .leading) { addApp; addFile; addCategory; reimport }
                }
            }

            Section("Permissions") {
                permissionRow(Mac("Accessibility"), pane: "Privacy_Accessibility", granted: permissions.accessibility,
                              detail: L("Jump to a specific window and double-tap a modifier key.")) {
                    Permissions.requestAccessibility()
                }
                permissionRow(Mac("Screen Recording"), pane: "Privacy_ScreenCapture", granted: permissions.screenRecording,
                              detail: L("Window previews when you hover a running app.")) {
                    Permissions.requestScreenRecording()
                }
                permissionRow(Mac("Full Disk Access"), pane: "Privacy_AllFiles", granted: permissions.fullDiskAccess,
                              detail: L("Find files in ⟦Documents⟧, ⟦Desktop⟧ and ⟦Downloads⟧. Turn on HomePad in the list that opens.")) {
                    Permissions.requestFullDiskAccess()
                }
                if !permissions.allGranted {
                    Text(L("Already switched on in ⟦System Settings⟧ but still red? Select HomePad there, remove it with −, then press Allow… again. This happens after an update changes the app's signature."))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section(Mac("Dock")) {
                Toggle(L("Hide the ⟦Dock⟧"), isOn: $dockHidden)
                    .onChange(of: dockHidden) { DockControl.setHidden($0) }
                Text(L("Turns on auto-hide with a very long delay, so the ⟦Dock⟧ never pops up. Cmd-Tab and ⟦Mission Control⟧ keep working."))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Reset") {
                Button("Reset to Defaults…") { confirmReset() }
                Text(L("Puts the shortcut, double-tap, hot corners, layout, menu-bar icon, ⟦Dock⟧ hiding and launch at login back to how they were at first. Your apps and categories are kept."))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Start Over…") { StartOver.confirm() }
                Text("As if HomePad had just been installed: its permissions are taken back in macOS, the Setup Guide shows again and HomePad restarts. You can choose to also forget your categories and settings.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("General") {
                Picker("Language", selection: Binding(get: { Localization.chosen ?? "" },
                                                      set: { Localization.choose($0.isEmpty ? nil : $0) })) {
                    Text("Same as the Mac").tag("")
                    Divider()
                    ForEach(Localization.options, id: \.code) { Text(verbatim: $0.title).tag($0.code) }
                }
                Text("HomePad restarts in the language you choose.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle("Show menu-bar icon", isOn: $showMenuBarIcon)
                    .onChange(of: showMenuBarIcon) { AppDelegate.shared?.setStatusItemVisible($0) }
                if !showMenuBarIcon {
                    Text("With the icon hidden, open HomePad with your shortcut or double-tap, or by launching the app again.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func confirmReset() {
        let alert = NSAlert()
        alert.messageText = L("Reset settings to their defaults?")
        alert.informativeText = L("This restores the shortcut (⌥Space), turns double-tap and hot corners off, sets 8 icons per row and the standard row height and icon spacing, shows the Running section (minimized windows hidden), shows the menu-bar icon, shows the ⟦Dock⟧ again and turns off launch at login. Your apps and categories are kept.")
        alert.addButton(withTitle: L("Reset"))
        alert.addButton(withTitle: L("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        shortcuts.update(.default)
        doubleTap = DoubleTapMonitor.Key.off.rawValue
        hotCorners = ""
        columns = 8
        rowHeight = RowMetrics.standard
        iconSpacing = TileMetrics.standardSpacing
        rememberSize = true
        rememberPosition = false
        showRunning = true
        hideMinimised = true
        showMenuBarIcon = true
        if dockHidden { dockHidden = false }
        if launchAtLogin { launchAtLogin = false }
    }

    private var addApp: some View { Button("Add App…") { Launcher.chooseAppsToPin() }.fixedSize() }
    private var addFile: some View { Button("Add File or Folder…") { Launcher.chooseFilesToPin() }.fixedSize() }
    private var addCategory: some View { Button("Add Category…") { Launcher.addCategory() }.fixedSize() }
    private var reimport: some View { Button(L("Re-import from ⟦Dock⟧…")) { confirmReimport() }.fixedSize() }

    private func confirmReimport() {
        let alert = NSAlert()
        alert.messageText = L("Replace Essentials with the apps in the ⟦Dock⟧?")
        alert.informativeText = L("Your current Essentials list and its order will be replaced. Other categories are kept.")
        alert.addButton(withTitle: L("Replace"))
        alert.addButton(withTitle: L("Cancel"))
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
                Text(recording ? L("Press keys…") : (store.isNone ? L("None") : store.shortcut.displayString))
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

/// Settings → Start Over: back to a first launch, to go through the Setup Guide and the permission requests again.
enum StartOver {
    static func confirm() {
        let alert = NSAlert()
        alert.messageText = L("Start over as if HomePad were new?")
        alert.informativeText = L("macOS takes back HomePad's permissions (⟦Accessibility⟧, ⟦Screen Recording⟧, ⟦Full Disk Access⟧), so it will ask for them again. The Setup Guide shows once more, and HomePad restarts.")
        let erase = NSButton(checkboxWithTitle: L("Also forget my categories and settings"), target: nil, action: nil)
        alert.accessoryView = erase
        alert.addButton(withTitle: L("Start Over"))
        alert.addButton(withTitle: L("Cancel"))
        guard PanelController.shared.keepVisible(during: { alert.runModal() }) == .alertFirstButtonReturn else { return }
        run(erasingSettings: erase.state == .on)
    }

    private static func run(erasingSettings: Bool) {
        let id = Bundle.main.bundleIdentifier ?? "local.mike.HomePad"
        let reset = Process()
        reset.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        reset.arguments = ["reset", "All", id]
        try? reset.run()
        reset.waitUntilExit()
        if reset.terminationStatus != 0 {
            let note = NSAlert()
            note.messageText = L("macOS didn't take the permissions back")
            note.informativeText = L("Remove HomePad yourself in ⟦System Settings⟧ → ⟦Privacy & Security⟧, under ⟦Accessibility⟧, ⟦Screen Recording⟧ and ⟦Full Disk Access⟧ (select it, then press −). HomePad starts over anyway.")
            PanelController.shared.keepVisible { _ = note.runModal() }
        }
        let defaults = UserDefaults.standard
        if erasingSettings {
            try? SMAppService.mainApp.unregister()
            defaults.removePersistentDomain(forName: id)
            // A fresh start stays fresh: the settings of the app's earlier names aren't copied back in.
            defaults.set(true, forKey: "migratedFromSpotlightPlus")
            defaults.set(true, forKey: "migratedFromStartMenu")
        } else {
            Onboarding.reset()
        }
        defaults.synchronize()
        Relaunch.afterQuitting(reopening: nil)
        NSApp.terminate(nil)
    }
}

/// Pick any of the four corners: a small screen with a spot in each corner to click.
struct HotCornerSetting: View {
    /// The explanation below it (Settings); the Setup Guide keeps to the essentials.
    var showsHelp = true
    @AppStorage(HotCornerMonitor.defaultsKey) private var stored = ""
    private var chosen: Set<HotCorner> { HotCornerMonitor.decode(stored) }
    /// Read again when Settings opens: it is macOS's setting and may have changed meanwhile.
    @State private var clashes: [HotCorner: String] = [:]

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Or hot corners")
                Text(summary).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                if !showsHelp {
                    Text("HomePad opens in the corner you push the pointer into.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            screen
        }
        .onAppear(perform: readClashes)
        // macOS's setting may change in System Settings beside this window: read it again every couple of seconds
        // (a quick preferences read) and when HomePad comes back to the front.
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in readClashes() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in readClashes() }
        .onChange(of: stored) { _ in
            HotCornerMonitor.shared.apply()
            readClashes()
        }
        let clashing = HotCorner.allCases.filter { chosen.contains($0) && clashes[$0] != nil }
        if !clashing.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(clashing.map { L("macOS also uses the corner “\($0.title)” for \(clashes[$0]!).") }.joined(separator: " ")
                     + " " + L("Both will happen there. Set that corner to “–” in macOS's ⟦Hot Corners⟧, or pick another corner here."))
                    .font(.caption).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                Button(L("Open macOS ⟦Hot Corners⟧…")) { SystemHotCorners.open() }
            }
        }
        if showsHelp {
            Text("Rest the pointer in a corner you picked and HomePad opens in that corner; do it again to close it. The shortcut and double-tap still open it in the middle.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var summary: String {
        let names = HotCorner.allCases.filter(chosen.contains).map(\.title)
        return names.isEmpty ? L("Off. Click a corner to use it.") : names.joined(separator: L(", "))
    }

    private var screen: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.25)))
            // The menu bar, so top and bottom read at a glance.
            VStack { Rectangle().fill(Color.primary.opacity(0.12)).frame(height: 7); Spacer() }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            ForEach(HotCorner.allCases) { corner in
                cornerButton(corner)
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: Alignment(horizontal: corner.isLeft ? .leading : .trailing,
                                                vertical: corner.isTop ? .top : .bottom))
                    .padding(4)
            }
        }
        .frame(width: 132, height: 84)
    }

    private func cornerButton(_ corner: HotCorner) -> some View {
        let on = chosen.contains(corner)
        return Button {
            var corners = chosen
            if on { corners.remove(corner) } else { corners.insert(corner) }
            stored = HotCornerMonitor.encode(corners)
        } label: {
            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(on ? Color.accentColor : Color.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(on ? L("\(corner.title) (on)") : corner.title)
        .accessibilityLabel(corner.title)
        .accessibilityValue(on ? L("on") : L("off"))
    }

    private func readClashes() {
        CFPreferencesAppSynchronize("com.apple.dock" as CFString)
        var found: [HotCorner: String] = [:]
        for corner in HotCorner.allCases { found[corner] = corner.systemAction }
        clashes = found
    }
}
