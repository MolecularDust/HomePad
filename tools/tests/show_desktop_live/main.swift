// Live integration fixture for tools/test_show_desktop_live.sh.
import AppKit
import SwiftUI
import ApplicationServices
import ScreenCaptureKit
import WebKit
func fail(_ message: String) -> Never {
    try? message.write(to: root.appendingPathComponent("failure.txt"), atomically: true, encoding: .utf8)
    try? Data().write(to: root.appendingPathComponent("done"))
    exit(1)
}
func require(_ condition: @autoclosure () -> Bool, _ message: String = "assertion failed") { if !condition() { fail(message) } }

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let deadline = Date().addingTimeInterval(5)
while ["A","B"].contains(where: { !FileManager.default.fileExists(atPath: root.appendingPathComponent("fixture-\($0).json").path) }) && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
let manifests = ["A","B"].map { try! JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("fixture-\($0).json"))) as! [String: Any] }
let fixturePIDs = Set(manifests.map { ($0["pid"] as! NSNumber).int32Value })
for pid in fixturePIDs {
    require(NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == "local.mike.HomePad.AnimationFixture", "only the test fixtures may be changed")
}
let normalIDs = Set(manifests.flatMap { ($0["normal"] as! [NSNumber]).map(\.uint32Value) })
let priorIDs = Set(manifests.map { ($0["prior"] as! NSNumber).uint32Value })
let dialogIDs = Set(manifests.map { ($0["dialog"] as! NSNumber).uint32Value })
func CGWindowListCopyWindowInfo(_ options: CGWindowListOption, _ id: CGWindowID) -> CFArray? {
    let all = CoreGraphics.CGWindowListCopyWindowInfo(options, id) as? [[String: Any]] ?? []
    return all.filter { info in
        let owner = info[kCGWindowOwnerPID as String] as? pid_t ?? -1
        return fixturePIDs.contains(owner) || owner == getpid()
    } as CFArray
}
enum Permissions {
    static var accessibility: Bool { AXIsProcessTrusted() }
    static var screenRecording: Bool { CGPreflightScreenCaptureAccess() }
    static func requestAccessibility() { fail("missing Accessibility permission") }
    static func requestScreenRecording() { fail("missing Screen Recording permission") }
}
final class PanelController { static let shared = PanelController(); func hide(restoreFocus: Bool) {} }
final class WindowPreviewController { static let shared = WindowPreviewController(); func hideNow() {} }
final class Taskbar {
    static let shared = Taskbar()
    static let height: CGFloat = 48
    var window: NSWindow?
    var frame: NSRect? { window?.frame }
    func screenRect(_ rect: CGRect) -> NSRect? { window?.convertToScreen(rect) }
}
final class TaskbarDrag: ObservableObject { static let shared = TaskbarDrag(); @Published var item: URL? }
final class TaskbarLabel { static let shared = TaskbarLabel(); func hover(_ text: String?, over: NSRect?) {} }
struct TaskbarHighlight: View { let on: Bool; let strong: Bool; var body: some View { Color.clear } }
struct FrameReader: View { @Binding var frame: CGRect; var body: some View { Color.clear } }
func L(_ text: String.LocalizationValue) -> String { String(localized: text) }
extension View { func localized() -> some View { self.environment(\.locale, Locale(identifier: "en")) } }
final class BarPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
final class DriftingWindow: NSWindow {
    override func deminiaturize(_ sender: Any?) {
        super.deminiaturize(sender)
        setFrame(frame.offsetBy(dx: 29, dy: 17), display: true, animate: false)
        contentView?.needsDisplay = true
    }
}
func layout(_ ids: Set<CGWindowID>) -> (order: [CGWindowID], frames: [CGWindowID: CGRect]) {
    let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], 0) as? [[String: Any]] ?? []
    var order: [CGWindowID] = []
    var frames: [CGWindowID: CGRect] = [:]
    for info in infos {
        guard let id = info[kCGWindowNumber as String] as? CGWindowID, ids.contains(id),
              let bounds = info[kCGWindowBounds as String] as? NSDictionary,
              let frame = CGRect(dictionaryRepresentation: bounds) else { continue }
        order.append(id)
        frames[id] = frame
    }
    return (order, frames)
}
func interleaveFixtures() {
    let lists = manifests.map { ($0["normal"] as! [NSNumber]).map(\.uint32Value) + [($0["dialog"] as! NSNumber).uint32Value] }
    let order = zip(lists[0], lists[1]).flatMap { [$0.0, $0.1] }
    var elements: [CGWindowID: AXUIElement] = [:]
    for pid in fixturePIDs {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXWindowsAttribute as CFString, &value)
        for element in value as? [AXUIElement] ?? [] {
            if let id = RemoteAX.windowID(of: element) { elements[id] = element }
        }
    }
    for id in order.reversed() {
        if let element = elements[id] {
            var pid: pid_t = 0
            AXUIElementGetPid(element, &pid)
            SkyLight.raisePreservingOthers(window: id, pid: pid)
            AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        }
    }
    Thread.sleep(forTimeInterval: 0.2)
    let actual = layout(Set(order)).order
    let owners = actual.compactMap { id -> pid_t? in
        guard let element = elements[id] else { return nil }
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        return pid
    }
    require(actual.count == 8 && zip(owners, owners.dropFirst()).filter { $0 != $1 }.count >= 3,
            "the fixture must start with interleaved app windows: \(actual)")
}
final class MarkerView: NSView {
    var paintCount = 0
    override func draw(_ dirtyRect: NSRect) {
        paintCount += 1
        NSColor(srgbRed: 0.875, green: 0.125, blue: 0.75, alpha: 1).setFill()
        bounds.fill()
        NSColor(srgbRed: 0.125, green: 0.875, blue: 0.25, alpha: 1).setFill()
        NSRect(x: bounds.midX, y: bounds.minY, width: bounds.width / 2, height: bounds.height).fill()
    }
}
final class BackdropView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor(srgbRed: 0.9, green: 0.9, blue: 0.9, alpha: 1).setFill()
        bounds.fill()
    }
}
final class BrowserFrames: NSObject, WKScriptMessageHandler {
    var count = 0
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        count += 1
    }
}
func brightness(_ image: CGImage) -> Double {
    let bitmap = NSBitmapImageRep(cgImage: image)
    var total = 0.0
    var count = 0
    for y in stride(from: 0, to: bitmap.pixelsHigh, by: 2) {
        for x in stride(from: 0, to: bitmap.pixelsWide, by: 2) {
            if let c = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) {
                total += (c.redComponent + c.greenComponent + c.blueComponent) / 3
                count += 1
            }
        }
    }
    return total / Double(count)
}
func findButton(_ element: AXUIElement, depth: Int = 0) -> AXUIElement? {
    guard depth < 20 else { return nil }
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, "AXIdentifier" as CFString, &value)
    if value as? String == "show-desktop" { return element }
    for name in [kAXChildrenAttribute, kAXWindowsAttribute, kAXContentsAttribute] {
        value = nil
        AXUIElementCopyAttributeValue(element, name as CFString, &value)
        for child in value as? [AXUIElement] ?? [] {
            if let found = findButton(child, depth: depth + 1) { return found }
        }
    }
    return nil
}
func fixtureState() -> (normal: [Bool], visible: Set<CGWindowID>, hidden: [Bool], prior: [Bool]) {
    var states: [Bool] = []
    var prior: [Bool] = []
    var hidden: [Bool] = []
    for pid in fixturePIDs {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 2)
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(app, kAXHiddenAttribute as CFString, &value)
        hidden.append(value as? Bool ?? false)
        AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
        for element in value as? [AXUIElement] ?? [] {
            guard let id = RemoteAX.windowID(of: element), normalIDs.contains(id) || priorIDs.contains(id) else { continue }
            var state: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &state)
            if let minimized = state as? Bool { if priorIDs.contains(id) { prior.append(minimized) } else { states.append(minimized) } }
        }
    }
    let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], 0) as? [[String: Any]] ?? []
    let visible = Set(infos.filter { fixturePIDs.contains($0[kCGWindowOwnerPID as String] as? pid_t ?? -1) }.compactMap { $0[kCGWindowNumber as String] as? CGWindowID })
    return (states, visible, hidden, prior)
}
final class Delegate: NSObject, NSApplicationDelegate {
    var bar: NSPanel!
    var local: NSWindow!
    var unbacked: NSWindow!
    var settings: NSWindow!
    var backdrop: NSPanel!
    var shadowRect = CGRect.zero
    var coverShadowBrightness: Double?
    var checks: [[String: Any]] = []
    var coverPresentedAt: TimeInterval?
    let browserFrames = BrowserFrames()
    func applicationDidFinishLaunching(_ note: Notification) {
        UserDefaults.standard.setVolatileDomain(["taskbarShowsNetwork": false, "taskbarShowsVolume": false, "taskbarShowsBattery": false, "taskbarShowsClock": false], forName: UserDefaults.argumentDomain)
        bar = BarPanel(contentRect: NSRect(x: 200, y: 80, width: 320, height: 48), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        bar.hidesOnDeactivate = false
        bar.level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue + 1)
        bar.contentView = NSHostingView(rootView: TaskbarTrayView().localized().frame(width: 320, height: 48, alignment: .trailing))
        Taskbar.shared.window = bar
        bar.orderFrontRegardless()
        backdrop = BarPanel(contentRect: NSRect(x: 720, y: 260, width: 230, height: 280), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        backdrop.level = NSWindow.Level(rawValue: 2)
        backdrop.hidesOnDeactivate = false
        backdrop.hasShadow = false
        backdrop.isOpaque = true
        backdrop.contentView = BackdropView(frame: NSRect(x: 0, y: 0, width: 230, height: 280))
        backdrop.orderFrontRegardless()
        local = DriftingWindow(contentRect: NSRect(x: 750, y: 300, width: 150, height: 160), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        local.title = "HomePad Local Test"
        local.contentView = MarkerView(frame: NSRect(x: 0, y: 0, width: 150, height: 160))
        let browserConfig = WKWebViewConfiguration()
        browserConfig.userContentController.add(browserFrames, name: "frames")
        let browser = WKWebView(frame: NSRect(x: 0, y: 75, width: 150, height: 70), configuration: browserConfig)
        local.contentView?.addSubview(browser)
        browser.loadHTMLString("""
            <html><body style="margin:0;background:#ddd;font:12px sans-serif"><script>
            let frame = 0;
            function paint() {
                document.body.textContent = 'Browser frame ' + (++frame);
                window.webkit.messageHandlers.frames.postMessage(frame);
                requestAnimationFrame(paint);
            }
            requestAnimationFrame(paint);
            </script></body></html>
            """, baseURL: nil)
        local.level = .floating // Keep the marker observable above the working app without activating the fixture.
        local.orderFrontRegardless()
        settings = NSWindow(contentRect: NSRect(x: 920, y: 350, width: 180, height: 180), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        settings.title = "HomePad Settings Test"
        settings.orderFrontRegardless()
        unbacked = NSWindow(contentRect: .zero, styleMask: [.titled, .miniaturizable], backing: .buffered, defer: true)
        Task { @MainActor in
            defer { try? Data().write(to: root.appendingPathComponent("done")); NSApp.terminate(nil) }
            try? await Task.sleep(nanoseconds: 300_000_000)
            let browserDeadline = Date().addingTimeInterval(5)
            while browserFrames.count < 3, Date() < browserDeadline { try? await Task.sleep(nanoseconds: 10_000_000) }
            require(browserFrames.count >= 3, "the embedded browser fixture did not start rendering")
            require(unbacked.windowNumber == -1)
            await Task.detached { interleaveFixtures() }.value
            let allIDs = normalIDs.union(dialogIDs).union([CGWindowID(local.windowNumber), CGWindowID(settings.windowNumber)])
            for cycle in 1...3 {
                let originalLayout = layout(allIDs)
                require(originalLayout.order.count == 10, "record every original test window's layout")
                shadowRect = CGRect(x: local.frame.minX + 40, y: local.frame.minY - 18, width: 70, height: 16)
                var originalShadow: Double?
                if #available(macOS 15.2, *) {
                    let rect = CGRect(x: shadowRect.minX, y: NSScreen.screens[0].frame.maxY - shadowRect.maxY, width: shadowRect.width, height: shadowRect.height)
                    originalShadow = brightness(try! await SCScreenshotManager.captureImage(in: rect))
                }
                guard let button = findButton(AXUIElementCreateApplication(getpid())) else { fail("actual taskbar button not found") }
                let minimizeStart = ProcessInfo.processInfo.systemUptime
                require(AXUIElementPerformAction(button, kAXPressAction as CFString) == .success, "actual button rejected first press")
                await waitForBatch(expectedMarker: false)
                let minimizeMS = Int((ProcessInfo.processInfo.systemUptime - minimizeStart) * 1000)
                guard let desktopPresentedAt = coverPresentedAt else { fail("desktop cover was never presented") }
                let desktopMS = Int((desktopPresentedAt - minimizeStart) * 1000)
                let first = await Task.detached { fixtureState() }.value
                require(first.normal.count == 6 && first.normal.allSatisfy { $0 }, "normal windows not minimized")
                require(first.visible.intersection(normalIDs.union(dialogIDs)).isEmpty, "cycle \(cycle): test windows still visible: \(first.visible.intersection(normalIDs.union(dialogIDs)).sorted()); hidden: \(first.hidden); minimized: \(first.normal)")
                require(first.hidden.count == 2 && first.hidden.allSatisfy { $0 }, "dialog fallback not remembered")
                require(local.isMiniaturized)
                require(!settings.isVisible, "HomePad's non-minimizable Settings window remains visible")
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard let restoreButton = findButton(AXUIElementCreateApplication(getpid())) else { fail("restore button disappeared") }
                let restoreStart = ProcessInfo.processInfo.systemUptime
                require(AXUIElementPerformAction(restoreButton, kAXPressAction as CFString) == .success, "actual button rejected restore press")
                await waitForBatch(expectedMarker: true)
                let restoreMS = Int((ProcessInfo.processInfo.systemUptime - restoreStart) * 1000)
                guard let windowsPresentedAt = coverPresentedAt else { fail("window scene was never presented") }
                let windowsMS = Int((windowsPresentedAt - restoreStart) * 1000)
                if let originalShadow, let restoredShadow = coverShadowBrightness {
                    require(abs(originalShadow - restoredShadow) < 0.025,
                            "restore shadow differs from the actual display: \(originalShadow) -> \(restoredShadow)")
                }
                require(windowsMS < 250, "saved windows must reappear without waiting for the Dock restore queue")
                let second = await Task.detached { fixtureState() }.value
                require(second.normal.count == 6 && second.normal.allSatisfy { !$0 }, "normal windows not restored")
                require(normalIDs.union(dialogIDs).isSubset(of: second.visible), "not every original test window is visible after restore")
                require(second.hidden.allSatisfy { !$0 }, "a test app was left hidden")
                require(second.prior.count == 2 && second.prior.allSatisfy { $0 }, "previously minimized windows must remain minimized")
                require(!local.isMiniaturized)
                require(settings.isVisible, "HomePad's non-minimizable Settings window was not restored")
                // Activation notifications can arrive after the AX calls return. Verify the layout stays correct.
                try? await Task.sleep(nanoseconds: 250_000_000)
                var shadowHandoffDifference = 0.0
                var shadowHandoffVerified = false
                if #available(macOS 15.2, *) {
                    guard let cachedShadow = coverShadowBrightness else { fail("restore shadow patch was not sampled") }
                    let rect = CGRect(x: shadowRect.minX, y: NSScreen.screens[0].frame.maxY - shadowRect.maxY, width: shadowRect.width, height: shadowRect.height)
                    let liveShadow = brightness(try! await SCScreenshotManager.captureImage(in: rect))
                    shadowHandoffDifference = abs(cachedShadow - liveShadow)
                    shadowHandoffVerified = true
                    require(shadowHandoffDifference < 0.025,
                            "shadow pops at handoff from saved image to live windows: \(cachedShadow) -> \(liveShadow)")
                }
                let restoredLayout = layout(allIDs)
                require(restoredLayout.order == originalLayout.order, "cycle \(cycle): stacking order changed: \(originalLayout.order) -> \(restoredLayout.order)")
                for (id, frame) in originalLayout.frames {
                    guard let restored = restoredLayout.frames[id] else { fail("a layout window disappeared") }
                    require(abs(frame.minX - restored.minX) < 1 && abs(frame.minY - restored.minY) < 1
                            && abs(frame.width - restored.width) < 1 && abs(frame.height - restored.height) < 1,
                            "cycle \(cycle): window \(id) moved or resized: \(frame) -> \(restored)")
                }
                checks.append(["cycle": cycle, "shadowHandoffVerified": shadowHandoffVerified, "shadowHandoffDifference": shadowHandoffDifference, "layoutWindowsVerified": restoredLayout.order.count, "geometryWindowsVerified": restoredLayout.frames.count, "windowsVisibleMilliseconds": windowsMS, "desktopVisibleMilliseconds": desktopMS, "minimizeMilliseconds": minimizeMS, "restoreMilliseconds": restoreMS, "normalWindowsRestored": second.normal.count + 1, "nonMinimizableWindowsRestored": dialogIDs.count + 1, "originalWindowsVisible": normalIDs.union(dialogIDs).intersection(second.visible).count + 2, "actualButtonPresses": 2, "previouslyMinimizedWindowsPreserved": second.prior.count])
            }
            try! JSONSerialization.data(withJSONObject: checks, options: [.prettyPrinted, .sortedKeys]).write(to: root.appendingPathComponent("results.json"))
        }
    }
    @MainActor func waitForBatch(expectedMarker: Bool? = nil) async {
        coverPresentedAt = nil
        coverShadowBrightness = nil
        var drawableUnderCover = false
        var browserRenderingUnderCover = false
        let paintsBeforeRestore = (local.contentView as? MarkerView)?.paintCount ?? 0
        let browserFramesBeforeRestore = browserFrames.count
        let deadline = Date().addingTimeInterval(20)
        while !ShowDesktop.shared.isBusy && Date() < deadline { try? await Task.sleep(nanoseconds: 5_000_000) }
        require(ShowDesktop.shared.isBusy, "button did not start a batch")
        while ShowDesktop.shared.isBusy && Date() < deadline {
            if expectedMarker == true, !local.isMiniaturized,
               local.occlusionState.contains(.visible),
               ((local.contentView as? MarkerView)?.paintCount ?? 0) > paintsBeforeRestore,
               NSApp.windows.contains(where: { $0.isVisible && $0.level == .screenSaver }) {
                drawableUnderCover = true
                if browserFrames.count >= browserFramesBeforeRestore + 3 { browserRenderingUnderCover = true }
            }
            if let expectedMarker, coverPresentedAt == nil,
               let panel = NSApp.windows.first(where: { $0.isVisible && $0.level == .screenSaver }),
               let view = panel.contentView as? NSImageView,
               let cgImage = view.image?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                coverPresentedAt = ProcessInfo.processInfo.systemUptime
                // Inspect only our own in-memory marker area. Minimize must already exclude the window, while
                // restore must already show it before waiting for the Dock's per-window animation queue.
                let bitmap = NSBitmapImageRep(cgImage: cgImage)
                let shadowPixels = CGRect(x: (shadowRect.minX - panel.frame.minX) / panel.frame.width * CGFloat(bitmap.pixelsWide),
                                          y: (panel.frame.maxY - shadowRect.maxY) / panel.frame.height * CGFloat(bitmap.pixelsHigh),
                                          width: shadowRect.width / panel.frame.width * CGFloat(bitmap.pixelsWide),
                                          height: shadowRect.height / panel.frame.height * CGFloat(bitmap.pixelsHigh))
                if let patch = cgImage.cropping(to: shadowPixels) { coverShadowBrightness = brightness(patch) }
                let point = local.convertToScreen(NSRect(x: 30, y: 30, width: 1, height: 1)).origin
                let x = Int((point.x - panel.frame.minX) / panel.frame.width * CGFloat(bitmap.pixelsWide))
                let y = Int((panel.frame.maxY - point.y) / panel.frame.height * CGFloat(bitmap.pixelsHigh))
                guard x >= 0, x < bitmap.pixelsWide, y >= 0, y < bitmap.pixelsHigh,
                      let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { fail("test marker is outside capture") }
                let rightPoint = local.convertToScreen(NSRect(x: 110, y: 30, width: 1, height: 1)).origin
                let rightX = Int((rightPoint.x - panel.frame.minX) / panel.frame.width * CGFloat(bitmap.pixelsWide))
                guard let right = bitmap.colorAt(x: rightX, y: y)?.usingColorSpace(.sRGB) else { fail("test marker is outside capture") }
                // Match the two-color pattern by channel dominance: display color management changes exact RGBs.
                let markerPresent = color.redComponent - color.greenComponent > 0.3
                    && color.blueComponent - color.greenComponent > 0.3
                    && right.greenComponent - right.redComponent > 0.3
                    && right.greenComponent - right.blueComponent > 0.3
                require(markerPresent == expectedMarker,
                        expectedMarker ? "restore still shows the empty desktop instead of the saved windows" : "minimize cover still shows the old window instead of the desktop")
            }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        require(!ShowDesktop.shared.isBusy, "button batch did not finish")
        if expectedMarker == true {
            require(drawableUnderCover, "the restored window remains occluded or cannot repaint before the cover disappears")
            require(browserRenderingUnderCover, "the browser renderer must resume producing frames before the cover disappears")
        }
    }
}
let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
