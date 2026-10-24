import AppKit
import SwiftUI
import Combine

/// First-run window: grant permissions and pick how to open the panel.
enum Onboarding {
    private static let doneKey = "onboardingCompleted"
    private static var window: NSWindow?
    private static var closer: WindowCloser?

    static var completed: Bool { UserDefaults.standard.bool(forKey: doneKey) }

    static func show() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: OnboardingView(finish: finish)))
            w.title = "Welcome to SpotlightPlus"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            let c = WindowCloser { UserDefaults.standard.set(true, forKey: doneKey); window = nil; closer = nil }
            w.delegate = c
            closer = c
            window = w
        }
        PanelController.shared.hide(restoreFocus: false)
        window?.center()
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
    @State private var hasAccessibility = Permissions.accessibility
    @State private var hasScreenRecording = Permissions.screenRecording
    private let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to SpotlightPlus").font(.system(size: 20, weight: .semibold))
                Text("Two quick steps and you're set. You can change everything later in Settings.")
                    .foregroundStyle(.secondary)
            }

            step("1. Allow access") {
                permissionRow("Screen Recording", granted: hasScreenRecording,
                              detail: "Shows a preview of each window when you hover a running app.") {
                    Permissions.requestScreenRecording()
                    Permissions.openSettings("Privacy_ScreenCapture")
                }
                permissionRow("Accessibility", granted: hasAccessibility,
                              detail: "Jumps to the window you pick, and powers the double-tap shortcut.") {
                    Permissions.requestAccessibility()
                }
                Text("macOS may ask you to reopen SpotlightPlus after you allow Screen Recording.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            step("2. Choose how to open it") {
                HStack {
                    Text("Keyboard shortcut")
                    Spacer()
                    ShortcutRecorder()
                }
                if shortcuts.conflict {
                    Text("That shortcut is already in use by another app. Pick a different one.")
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
                        hasAccessibility = Permissions.accessibility
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
        .onReceive(poll) { _ in
            hasAccessibility = Permissions.accessibility
            hasScreenRecording = Permissions.screenRecording
        }
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

    private func permissionRow(_ title: String, granted: Bool, detail: String, request: @escaping () -> Void) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Button("Allow…", action: request)
            }
        }
    }
}
