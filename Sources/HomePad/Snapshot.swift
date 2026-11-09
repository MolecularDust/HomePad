#if DEBUG
import AppKit
import SwiftUI

/// Debug builds only: `-HomePadSnapshotDir <folder>` draws HomePad's windows (each Settings tab, the panel, the Setup Guide)
/// into PNGs there and quits, to check layouts such as a translation or right-to-left without screen access.
/// tools/snapshot.sh runs it.
enum Snapshot {
    static func startIfAsked() {
        guard let dir = UserDefaults.standard.string(forKey: "HomePadSnapshotDir") else { return }
        var steps: [(String, () -> Void)] = [
            ("panel", { PanelController.shared.show() }),
            ("setup", { Onboarding.show() }),
        ]
        // Each Settings tab as its window shows it, and at full height (for what scrolls out of the window).
        for tab in SettingsTab.allCases {
            steps.append(("settings-\(tab.rawValue)", {
                AppDelegate.shared?.openSettings()
                AppDelegate.shared?.settingsTabs?.select(tab)
            }))
            steps.append(("full-\(tab.rawValue)", {
                let view = NSHostingView(rootView: tab.view.localized().fixedSize(horizontal: false, vertical: true))
                let window = NSWindow(contentRect: NSRect(x: 40, y: 0, width: SettingsTabs.width, height: view.fittingSize.height),
                                      styleMask: [.titled], backing: .buffered, defer: false)
                window.contentView = view
                window.orderFrontRegardless()
            }))
        }
        func run(_ i: Int) {
            guard i < steps.count else { NSApp.terminate(nil); return }
            NSApp.windows.forEach { if $0.isVisible { $0.orderOut(nil) } }
            steps[i].1()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                let list = NSApp.windows.map { "\(steps[i].0): \(type(of: $0)) visible=\($0.isVisible) \(Int($0.frame.width))x\(Int($0.frame.height))" }
                if let h = try? FileHandle(forWritingTo: URL(fileURLWithPath: dir).appendingPathComponent("info.txt")) {
                    h.seekToEndOfFile(); h.write((list.joined(separator: "\n") + "\n").data(using: .utf8)!); try? h.close()
                }
                // The panel closes as soon as HomePad isn't the app in front, which it isn't while you work in
                // another one; drawing it doesn't need it on screen.
                let shown = NSApp.windows.filter { ($0.isVisible || (steps[i].0 == "panel" && $0 is SpotlightPanel)) && $0.frame.width > 100 }
                for (n, window) in shown.enumerated() {
                    save(window, to: URL(fileURLWithPath: dir).appendingPathComponent("\(steps[i].0)-\(n).png"))
                }
                run(i + 1)
            }
        }
        let info = "localization: \(Bundle.main.preferredLocalizations) direction: \(NSApp.userInterfaceLayoutDirection == .rightToLeft ? "rtl" : "ltr")\n"
        try? info.write(to: URL(fileURLWithPath: dir).appendingPathComponent("info.txt"), atomically: true, encoding: .utf8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { run(0) }
    }

    private static func save(_ window: NSWindow, to url: URL) {
        // The frame view includes the title bar; the content view alone would miss it.
        guard let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
#endif
