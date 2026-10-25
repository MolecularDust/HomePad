import AppKit
import SwiftUI
import Combine

/// First-run window: grant permissions and pick how to open the panel.
enum Onboarding {
    private static let doneKey = "onboardingCompleted"
    private static var window: NSWindow?
    private static var closer: WindowCloser?

    static var completed: Bool { UserDefaults.standard.bool(forKey: doneKey) }
    static var isOpen: Bool { window?.isVisible == true }

    /// Done without showing it: every permission is already on (after a reinstall or a rename, say).
    static func markCompleted() { UserDefaults.standard.set(true, forKey: doneKey) }

    /// It shows again at the next launch (Start Over).
    static func reset() { UserDefaults.standard.removeObject(forKey: doneKey) }

    static func show() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: OnboardingView(finish: finish)))
            w.title = "Welcome to HomePad"
            w.styleMask = [.titled, .closable]
            // An empty toolbar gives the full-height title bar regular Mac apps have.
            w.toolbar = NSToolbar(identifier: "OnboardingWindow")
            w.toolbarStyle = .unified
            w.isReleasedWhenClosed = false
            let c = WindowCloser { UserDefaults.standard.set(true, forKey: doneKey); window = nil; closer = nil }
            w.delegate = c
            closer = c
            window = w
            // Centered the first time; after that it stays where you put it, also across Quit & Reopen.
            if !w.setFrameUsingName("SetupGuide") { w.center() }
            w.setFrameAutosaveName("SetupGuide")
        }
        PanelController.shared.hide(restoreFocus: false)
        activateSelf()
        window?.makeKeyAndOrderFront(nil)
    }

    private static func finish() { window?.close() }

    private final class WindowCloser: NSObject, NSWindowDelegate {
        let onClose: () -> Void
        init(onClose: @escaping () -> Void) { self.onClose = onClose }
        func windowWillClose(_ notification: Notification) { onClose() }
    }
}

struct OnboardingView: View {
    let finish: () -> Void
    @ObservedObject private var shortcuts = ShortcutStore.shared
    @AppStorage(DoubleTapMonitor.defaultsKey) private var doubleTap = DoubleTapMonitor.Key.off.rawValue
    @ObservedObject private var permissions = PermissionStatus.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to HomePad").font(.system(size: 20, weight: .semibold))
                Text("Two quick steps and you're set. You can change everything later in Settings.")
                    .foregroundStyle(.secondary)
            }

            step("1. Allow access") {
                permissionRow("Screen Recording", pane: "Privacy_ScreenCapture", granted: permissions.screenRecording,
                              detail: "Shows a preview of each window when you hover a running app.") {
                    Permissions.requestScreenRecording()
                }
                permissionRow("Accessibility", pane: "Privacy_Accessibility", granted: permissions.accessibility,
                              detail: "Jumps to the window you pick, and powers the double-tap shortcut.") {
                    Permissions.requestAccessibility()
                }
                permissionRow("Full Disk Access", pane: "Privacy_AllFiles", granted: permissions.fullDiskAccess,
                              detail: "Finds files in Documents, Desktop and Downloads. Add HomePad with + if it isn't listed.") {
                    Permissions.openSettings("Privacy_AllFiles")
                }
                Text("macOS may ask you to reopen HomePad after you allow Screen Recording or Full Disk Access.")
                    .font(.caption).foregroundStyle(.secondary)
                if !permissions.allGranted {
                    Text("Already switched on in System Settings but still red? Select HomePad there, remove it with −, then press Allow… again. This happens after an update changes the app's signature.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            step("2. Choose how to open it") {
                HStack {
                    Text("Keyboard shortcut")
                    Spacer()
                    ShortcutRecorder()
                }
                if let owner = shortcuts.conflict {
                    Text("That shortcut is already in use by \(owner.summary). Pick a different one.")
                        .font(.caption).foregroundStyle(.red)
                }
                HStack {
                    Text("Or double-tap a key")
                    Spacer()
                    Picker("", selection: $doubleTap) {
                        ForEach(DoubleTapMonitor.Key.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .onChange(of: doubleTap) { _ in
                        DoubleTapMonitor.shared.apply()
                        permissions.refresh()
                    }
                }
            }

            HStack {
                Spacer()
                Button("Get started", action: finish).keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
        .onAppear { PermissionStatus.shared.watch(true) }
        .onDisappear { PermissionStatus.shared.watch(false) }
    }

    private func step<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 14, weight: .semibold))
            VStack(alignment: .leading, spacing: 10) { content() }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
        }
    }

    private func permissionRow(_ title: String, pane: String, granted: Bool, detail: String, request: @escaping () -> Void) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            PermissionButton(granted: granted, pane: pane, request: request)
        }
    }
}
