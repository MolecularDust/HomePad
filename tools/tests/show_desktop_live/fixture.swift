// Live integration fixture for tools/test_show_desktop_live.sh.
import AppKit
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let tag = CommandLine.arguments.last ?? "A"
// Reproduce apps that acknowledge but ignore minimization while hidden.
final class VisibleOnlyWindow: NSWindow {
    override func setAccessibilityMinimized(_ minimized: Bool) {
        guard !NSApp.isHidden else { return }
        super.setAccessibilityMinimized(minimized)
        if !minimized && styleMask.contains(.miniaturizable) {
            var restored = frame.offsetBy(dx: 37, dy: 23)
            restored.size.width += 11
            setFrame(restored, display: true, animate: false)
        }
    }
}
final class Delegate: NSObject, NSApplicationDelegate {
    var windows: [NSWindow] = []
    func applicationDidFinishLaunching(_ note: Notification) {
        for index in 0..<4 {
            let style: NSWindow.StyleMask = index == 3 ? [.titled, .closable] : [.titled, .closable, .miniaturizable, .resizable]
            let window: NSWindow = tag == "B"
                ? VisibleOnlyWindow(contentRect: NSRect(x: 100 + index * 150, y: 180, width: 140, height: 150), styleMask: style, backing: .buffered, defer: false)
                : NSWindow(contentRect: NSRect(x: 100 + index * 150, y: 400, width: 140, height: 150), styleMask: style, backing: .buffered, defer: false)
            window.title = "HomePad Test \(tag) \(index == 3 ? "non-minimizable" : "normal") \(index)"
            window.orderFrontRegardless()
            windows.append(window)
        }
        let prior = NSWindow(contentRect: NSRect(x: 100, y: 600, width: 140, height: 150), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        prior.title = "Already minimized test window"
        prior.orderFrontRegardless()
        prior.miniaturize(nil)
        windows.append(prior)
        let report: [String: Any] = ["pid": getpid(), "normal": windows.prefix(3).map(\.windowNumber), "dialog": windows[3].windowNumber, "prior": prior.windowNumber]
        try! JSONSerialization.data(withJSONObject: report).write(to: root.appendingPathComponent("fixture-\(tag).json"))
        let deadline = Date().addingTimeInterval(60)
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if FileManager.default.fileExists(atPath: root.appendingPathComponent("done").path) || Date() > deadline { NSApp.terminate(nil) }
        }
    }
    func applicationWillTerminate(_ note: Notification) {
        try? Data().write(to: root.appendingPathComponent("fixture-\(tag)-stopped"))
    }

}
let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
