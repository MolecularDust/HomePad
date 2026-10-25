import AppKit
import SwiftUI
import ScreenCaptureKit
import ApplicationServices

// MARK: - Permissions

enum Permissions {
    static var screenRecording: Bool { CGPreflightScreenCaptureAccess() }
    static var accessibility: Bool { AXIsProcessTrusted() }
    /// Full Disk Access has no API to ask or check; being able to open the system's privacy database means it's on.
    /// Without it, macOS leaves files in Documents, Desktop and Downloads out of the search results.
    static var fullDiskAccess: Bool {
        FileHandle(forReadingAtPath: "/Library/Application Support/com.apple.TCC/TCC.db") != nil
    }

    /// Our panels float above ordinary windows, which would hide the system's permission dialog behind them.
    private static func clearFloatingWindows() {
        PanelController.shared.hide(restoreFocus: false)
        WindowPreviewController.shared.hideNow()
    }

    /// macOS's own Screen Recording prompt (the padlock) comes first: its Open System Settings button closes it and
    /// opens the list with HomePad already in it. HomePad opening System Settings as well used to show the list before
    /// HomePad was added, with the prompt left on top. macOS shows that prompt only once, so when none appears,
    /// HomePad opens the list itself.
    static func requestScreenRecording() {
        guard !screenRecording else { return }      // already allowed: never ask again
        clearFloatingWindows()
        PermissionStatus.shared.expectGrant()
        _ = CGRequestScreenCaptureAccess()
        // On recent macOS the call above doesn't always put HomePad in System Settings' Screen & System Audio
        // Recording list (after a permissions reset it often doesn't), so the switch can't be turned on. Asking
        // ScreenCaptureKit for the windows on screen does list the app, reliably.
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { _, _ in }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if !systemPromptShowing { openSettings("Privacy_ScreenCapture") }
        }
    }

    /// The padlock prompt macOS shows for privacy permissions is on screen. (Window owners can be read without
    /// Screen Recording; only window titles can't.)
    private static var systemPromptShowing: Bool {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.contains { $0[kCGWindowOwnerName as String] as? String == "universalAccessAuthWarn" }
    }

    static func requestAccessibility() {
        guard !accessibility else { return }        // already allowed: never ask again
        clearFloatingWindows()
        PermissionStatus.shared.expectGrant()
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    static func openSettings(_ pane: String) {
        PermissionStatus.shared.expectGrant()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// The three permissions, shared by Settings, the Setup Guide and the search hint. Checked again whenever the app
/// comes to the front (after a visit to System Settings, say), and every two seconds only while a window that shows
/// them is open, so its buttons turn green while you switch a permission on next to it. (Each view used to check for
/// itself: three times per keystroke in search, and every second in Settings.)
final class PermissionStatus: ObservableObject {
    static let shared = PermissionStatus()
    @Published private(set) var accessibility = Permissions.accessibility
    @Published private(set) var screenRecording = Permissions.screenRecording
    @Published private(set) var fullDiskAccess = Permissions.fullDiskAccess
    private var watchers = 0
    private var timer: Timer?
    /// What HomePad does when a permission it asked for is switched on (bring itself back to the front).
    var onGranted: (() -> Void)?
    private var waitTimer: Timer?
    private var waitUntil = Date.distantPast
    /// Waiting for a permission asked for: System Settings is in front, and HomePad comes back once it's on.
    private(set) var isWaiting = false
    private var grantedAt = Date.distantPast
    /// A quit from another process now is most likely System Settings' Quit & Reopen: still waiting, or a permission
    /// came on in the last few minutes. (Full Disk Access counts as on at once, before Quit & Reopen is even offered.)
    var expectsQuitAndReopen: Bool { isWaiting || Date().timeIntervalSince(grantedAt) < 300 }

    private init() {
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        let a = Permissions.accessibility, s = Permissions.screenRecording, f = Permissions.fullDiskAccess
        let newlyGranted = (a && !accessibility) || (s && !screenRecording) || (f && !fullDiskAccess)
        if a != accessibility { accessibility = a }
        if s != screenRecording { screenRecording = s }
        if f != fullDiskAccess { fullDiskAccess = f }
        if newlyGranted, isWaiting {
            grantedAt = Date()
            stopWaiting()
            onGranted?()
        }
    }

    /// A permission was asked for. For the next five minutes it's checked every second, so HomePad comes back to the
    /// front as soon as the switch is turned on in System Settings. (Screen Recording and Full Disk Access usually
    /// only count after a restart; System Settings then offers Quit & Reopen, and HomePad relaunches itself.)
    func expectGrant() {
        waitUntil = Date().addingTimeInterval(300)
        isWaiting = true
        guard waitTimer == nil else { return }
        waitTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if Date() > self.waitUntil { self.stopWaiting() } else { self.refresh() }
        }
    }

    private func stopWaiting() {
        isWaiting = false
        waitTimer?.invalidate()
        waitTimer = nil
    }

    /// A window showing the permissions opened (true) or closed (false).
    func watch(_ on: Bool) {
        watchers = max(0, watchers + (on ? 1 : -1))
        if watchers > 0, timer == nil {
            refresh()
            timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
        } else if watchers == 0 {
            timer?.invalidate()
            timer = nil
        }
    }

    var allGranted: Bool { accessibility && screenRecording && fullDiskAccess }
}

/// Red while the permission is missing or switched off, green once it's on.
/// Missing: asks for it. Allowed: opens that permission's pane in System Settings, to review or switch it off.
struct PermissionButton: View {
    let granted: Bool
    let pane: String
    let request: () -> Void

    var body: some View {
        Button(action: { granted ? Permissions.openSettings(pane) : request() }) {
            Label(granted ? "Allowed" : "Allow…",
                  systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(granted ? Color.green : Color.red))
        }
        .buttonStyle(.plain)
        .help(granted ? "Open this permission in System Settings" : "Allow this permission")
    }
}

// MARK: - Windows of an app

struct AppWindow: Identifiable {
    let id: CGWindowID
    let title: String
    let frame: CGRect
    var image: NSImage?
    /// True for a window on a Space other than the one showing now.
    var onOtherSpace = false
    /// False when Accessibility can't find this window's close button (the cross is then hidden).
    var canClose = true
    /// 1, 2, 3 ... in Mission Control's order; 0 when unknown.
    var spaceNumber = 0
}

enum WindowCatalog {
    static let thumbnailSize = CGSize(width: 180, height: 112)

    /// Lists an app's windows with thumbnails. Needs Screen Recording permission. Runs off the main thread: asking
    /// another app about its windows waits for that app's answer.
    /// `fresh` skips the shared window list kept from the last couple of seconds (after a window was closed).
    static func windows(for pid: pid_t, fresh: Bool = false) async -> [AppWindow] {
        guard Permissions.screenRecording else { return [] }
        async let listed = Task.detached(priority: .userInitiated) { realWindows(for: pid) }.value
        guard let content = await ShareableWindows.shared.content(fresh: fresh) else { return [] }
        let ordered = await listed
        let shareable = Dictionary(content.windows.filter { $0.owningApplication?.processID == pid }.map { ($0.windowID, $0) },
                                   uniquingKeysWith: { first, _ in first })
        let found = ordered.compactMap { r in shareable[r.id].map { (real: r, window: $0) } }

        // All thumbnails at once, rather than one after another.
        let images = await withTaskGroup(of: (CGWindowID, CGImage?).self) { group -> [CGWindowID: CGImage] in
            for item in found { group.addTask { (item.window.windowID, await thumbnail(of: item.window)) } }
            var images: [CGWindowID: CGImage] = [:]
            for await (id, image) in group { images[id] = image }
            return images
        }
        let result = found.map { item in
            AppWindow(id: item.window.windowID, title: item.window.title ?? "", frame: item.window.frame,
                      image: images[item.window.windowID].map { NSImage(cgImage: $0, size: NSSize(width: $0.width / 2, height: $0.height / 2)) },
                      onOtherSpace: item.real.onOtherSpace, spaceNumber: item.real.spaceNumber)
        }
        // Whether each window has a close button to press. A window on another Space can only be reached by a long
        // search (see RemoteAX), so its cross is shown and the search happens only if it is clicked.
        return await Task.detached(priority: .userInitiated) { () -> [AppWindow] in
            let trusted = Permissions.accessibility
            return result.map { window in
                var w = window
                w.canClose = !trusted || window.onOtherSpace || closeButton(for: window, pid: pid) != nil
                return w
            }
        }.value
    }

    /// At twice the thumbnail size, for sharp Retina display.
    private static func thumbnail(of window: SCWindow) async -> CGImage? {
        guard #available(macOS 14.0, *) else { return nil }   // SCScreenshotManager needs macOS 14
        let config = SCStreamConfiguration()
        let scale = min(thumbnailSize.width * 2 / window.frame.width, thumbnailSize.height * 2 / window.frame.height)
        config.width = max(1, Int(window.frame.width * scale))
        config.height = max(1, Int(window.frame.height * scale))
        config.showsCursor = false
        let filter = SCContentFilter(desktopIndependentWindow: window)
        return try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    /// Window titles via Accessibility, used when Screen Recording isn't allowed.
    static func titles(for pid: pid_t) -> [String] {
        guard Permissions.accessibility else { return [] }
        return axWindows(pid).compactMap { axString($0, kAXTitleAttribute) }.filter { !$0.isEmpty }
    }

    // MARK: What counts as a window

    struct RealWindow {
        let id: CGWindowID
        let frame: CGRect
        let onOtherSpace: Bool
        let spaceNumber: Int
        /// From the window server; empty without the Screen Recording permission.
        var title = ""

    }

    /// The windows a person would call windows: visible ones, minimised ones, and ones on other Spaces. Apps also
    /// keep many hidden helper windows (DaVinci Resolve has dozens). Those belong to no Space, which is how
    /// they're told apart from a real window on another desktop.
    /// Needs no permission, so it works before Screen Recording or Accessibility are allowed.
    /// Finding minimised windows means asking the app itself, which waits for its answer (DaVinci Resolve took up to
    /// 425 ms); `askingApp: false` leaves them out and only asks the window server, which takes a few ms.
    static func realWindows(for pid: pid_t, askingApp: Bool = true) -> [RealWindow] {
        let minimised = askingApp ? axWindows(pid).filter { axBool($0, kAXMinimizedAttribute) == true }.compactMap(axFrame) : []
        let infos = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
        let activeSpace = SkyLight.activeSpace
        let numbers = SkyLight.spaceNumbers()
        let found: [RealWindow] = infos.compactMap { info in
            guard (info[kCGWindowOwnerPID as String] as? Int32) == pid,
                  // Normal windows are level 0, but some apps (DaVinci Resolve) raise theirs to 3 or 4 while active;
                  // palettes and panels sit at up to 8. Menu bar items, the Dock and the like are far above.
                  let level = info[kCGWindowLayer as String] as? Int, (0...8).contains(level),
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let number = info[kCGWindowNumber as String] as? CGWindowID,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds),
                  rect.width > 80, rect.height > 60 else { return nil }
            let onScreen = (info[kCGWindowIsOnscreen as String] as? Bool) ?? ((info[kCGWindowIsOnscreen as String] as? Int) == 1)
            let spaces = SkyLight.spaces(of: number)
            let placed = SkyLight.isOrderedIn(number)
            let isMinimised = minimised.contains(where: near(rect))
            // Seen from another Space every window there is off screen, so whether it is placed on its Space is what
            // tells a shown window from a hidden one. A window that belongs to a Space but isn't placed on it is left
            // out, from every Space alike: the app no longer counts it (Opera's own Window menu leaves such windows out
            // too), and nothing brings it back.
            let otherSpace = (activeSpace.map { active in !spaces.isEmpty && !spaces.contains(active) } ?? false) && placed != false
            guard onScreen || otherSpace || isMinimised else { return nil }
            // Minimised windows can belong to no Space; they are on the one showing.
            let spaceNo = spaces.first.flatMap { numbers[$0] } ?? activeSpace.flatMap { numbers[$0] } ?? 0
            return RealWindow(id: number, frame: rect, onOtherSpace: otherSpace, spaceNumber: spaceNo,
                              title: info[kCGWindowName as String] as? String ?? "")
        }
        // By Space (in Mission Control's order), then front to back.
        return found.enumerated()
            .sorted { ($0.element.spaceNumber, $0.offset) < ($1.element.spaceNumber, $1.offset) }
            .map(\.element)
    }

    // MARK: Closing windows

    /// How many windows can really be closed. Closing works by pressing each window's close button through
    /// Accessibility, and some apps (DaVinci Resolve) draw their own windows and expose no buttons to press.
    /// Without the Accessibility permission this can't be known, so any visible window counts.
    static func closableWindowCount(for pid: pid_t) -> Int {
        guard Permissions.accessibility else { return realWindows(for: pid).count }
        return axWindows(pid).filter { closeButton(of: $0) != nil }.count
    }

    /// Presses the close button of each of the app's windows. Needs the Accessibility permission.
    static func closeWindows(of app: NSRunningApplication) {
        WindowPreviewController.shared.hideNow()
        guard Permissions.accessibility else { Permissions.requestAccessibility(); return }
        for window in axWindows(app.processIdentifier) {
            if let button = closeButton(of: window) { AXUIElementPerformAction(button, kAXPressAction as CFString) }
        }
    }

    private static func closeButton(of window: AXUIElement) -> AXUIElement? {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &ref)
        return ref.map { $0 as! AXUIElement }
    }

    // MARK: Jumping to a window

    /// The panel goes at once; finding the window (which waits for the app's answers, and for a window on another
    /// Space can mean a search of a few seconds) happens in the background.
    static func focus(_ window: AppWindow, of app: NSRunningApplication) {
        PanelController.shared.hide(restoreFocus: false)
        WindowPreviewController.shared.hideNow()
        DispatchQueue.global(qos: .userInteractive).async { bringForward(window, of: app) }
    }

    private static func bringForward(_ window: AppWindow, of app: NSRunningApplication) {
        // A window on another Space can't be reached through Accessibility. Activating the app makes macOS
        // switch to a Space where it has windows; naming the window first points it at this one.
        if window.onOtherSpace {
            SkyLight.focus(window: window.id, pid: app.processIdentifier)
            if let element = axWindow(for: window, pid: app.processIdentifier, deep: true) {
                AXUIElementPerformAction(element, kAXRaiseAction as CFString)
                AXUIElementSetAttributeValue(AXUIElementCreateApplication(app.processIdentifier), kAXFrontmostAttribute as CFString, kCFBooleanTrue)
            }
            DispatchQueue.main.async { app.activate(options: [.activateAllWindows]) }
            return
        }
        guard Permissions.accessibility else {
            DispatchQueue.main.async {
                Permissions.requestAccessibility()
                app.activate(options: [.activateAllWindows])
            }
            return
        }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        if let match = axWindow(for: window, pid: app.processIdentifier) {
            AXUIElementSetAttributeValue(match, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            AXUIElementPerformAction(match, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(axApp, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        }
        DispatchQueue.main.async { app.activate(options: []) }
    }

    /// Closes one specific window by pressing its close button. Needs the Accessibility permission.
    @discardableResult
    static func close(_ window: AppWindow, of app: NSRunningApplication) -> Bool {
        guard Permissions.accessibility else { Permissions.requestAccessibility(); return false }
        guard let button = closeButton(for: window, pid: app.processIdentifier, deep: true) else { return false }
        return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
    }

    private static func closeButton(for window: AppWindow, pid: pid_t, deep: Bool = false) -> AXUIElement? {
        axWindow(for: window, pid: pid, deep: deep).flatMap(closeButton(of:))
    }

    /// The Accessibility element for a window from the window list: by title and position, then position, then title.
    private static func axWindow(for window: AppWindow, pid: pid_t, deep: Bool = false) -> AXUIElement? {
        if window.onOtherSpace { return RemoteAX.element(for: window.id, pid: pid, deep: deep) }
        let candidates = axWindows(pid)
        return candidates.first { axString($0, kAXTitleAttribute) == window.title && axFrame($0).map(near(window.frame)) == true }
            ?? candidates.first { axFrame($0).map(near(window.frame)) == true }
            ?? candidates.first { !window.title.isEmpty && axString($0, kAXTitleAttribute) == window.title }
            ?? RemoteAX.element(for: window.id, pid: pid, deep: deep)
    }

    private static func near(_ target: CGRect) -> (CGRect) -> Bool {
        { abs($0.minX - target.minX) < 4 && abs($0.minY - target.minY) < 4
            && abs($0.width - target.width) < 4 && abs($0.height - target.height) < 4 }
    }

    private static func axWindows(_ pid: pid_t) -> [AXUIElement] {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXWindowsAttribute as CFString, &ref)
        return ref as? [AXUIElement] ?? []
    }

    private static func axBool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(element, attribute as CFString, &ref)
        return ref as? Bool
    }

    private static func axString(_ element: AXUIElement, _ attribute: String) -> String? {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(element, attribute as CFString, &ref)
        return ref as? String
    }

    private static func axFrame(_ element: AXUIElement) -> CGRect? {
        var pos: CFTypeRef?, size: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &pos)
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size)
        var p = CGPoint.zero, s = CGSize.zero
        guard let pos, let size,
              AXValueGetValue(pos as! AXValue, .cgPoint, &p),
              AXValueGetValue(size as! AXValue, .cgSize, &s) else { return nil }
        return CGRect(origin: p, size: s)
    }
}

/// The list of every window on screen that ScreenCaptureKit hands out, kept for two seconds: fetching it takes
/// 20 to 50 ms, and moving along the running apps would otherwise fetch it for each one.
actor ShareableWindows {
    static let shared = ShareableWindows()
    private var content: SCShareableContent?
    private var fetched = 0.0

    func content(fresh: Bool) async -> SCShareableContent? {
        if !fresh, let content, CACurrentMediaTime() - fetched < 2 { return content }
        content = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
        fetched = CACurrentMediaTime()
        return content
    }
}

// MARK: - Hover popup

final class WindowPreviewModel: ObservableObject {
    @Published var app: NSRunningApplication?
    @Published var windows: [AppWindow] = []
    @Published var fallbackTitles: [String] = []
    @Published var loading = false
    @Published var needsPermission = false
}

/// A small non-activating panel next to a hovered running app, showing a thumbnail per open window.
final class WindowPreviewController {
    static let shared = WindowPreviewController()

    private let model = WindowPreviewModel()
    private var panel: NSPanel!
    private var host: NSHostingView<WindowPreviewView>!
    private var overTile = false
    private var overPreview = false
    private var showWork: DispatchWorkItem?
    private var hideWork: DispatchWorkItem?
    private var generation = 0
    private var lastTile = CGRect.zero
    private var mouseMonitor: Any?
    /// What was loaded for the app last pointed at: loading starts the moment the pointer arrives, so the
    /// thumbnails are usually ready by the time the popup appears.
    private var loaded: (pid: pid_t, windows: [AppWindow], titles: [String])?

    private init() {
        host = NSHostingView(rootView: WindowPreviewView(model: model))
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = NSWindow.Level(rawValue: NSWindow.Level.modalPanel.rawValue + 1)
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.maskImage = SpotlightPanel.roundedMask(radius: 12)
        host.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            host.topAnchor.constraint(equalTo: effect.topAnchor),
            host.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
        p.contentView = effect
        panel = p
    }

    /// `tile` is the hovered tile's frame in the main panel's coordinates (origin top-left).
    func hover(app: NSRunningApplication?, over: Bool, tile: CGRect) {
        overTile = over
        // With a mouse button down the user is clicking or dragging the tile, not looking for its windows.
        if over, NSEvent.pressedMouseButtons != 0 || PanelState.shared.isDragging { return }
        if over, let app {
            hideWork?.cancel()
            if panel.isVisible, model.app?.processIdentifier == app.processIdentifier { return }
            showWork?.cancel()
            load(app)
            // A short wait before the first popup, so passing over a tile doesn't flash one. Once a popup is open,
            // moving to the next running app shows its windows straight away.
            if panel.isVisible { show(app, tile: tile); return }
            let work = DispatchWorkItem { [weak self] in self?.show(app, tile: tile) }
            showWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
        } else {
            showWork?.cancel()
            scheduleHide()
        }
    }

    func previewHover(_ over: Bool) {
        overPreview = over
        if over { hideWork?.cancel() } else { scheduleHide() }
    }

    func hideNow() {
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        mouseMonitor = nil
        showWork?.cancel()
        hideWork?.cancel()
        generation += 1
        loaded = nil
        overTile = false
        overPreview = false
        panel.orderOut(nil)
    }

    /// Starts finding the app's windows (or, without Screen Recording, their titles) in the background.
    private func load(_ app: NSRunningApplication) {
        generation += 1
        let mine = generation
        let pid = app.processIdentifier
        loaded = nil
        let permitted = Permissions.screenRecording
        Task { @MainActor in
            let windows = permitted ? await WindowCatalog.windows(for: pid) : []
            let titles = permitted ? [] : await Task.detached { WindowCatalog.titles(for: pid) }.value
            guard mine == self.generation else { return }
            self.loaded = (pid, windows, titles)
            if self.panel.isVisible, self.model.app?.processIdentifier == pid { self.apply(windows: windows, titles: titles) }
        }
    }

    private func apply(windows: [AppWindow], titles: [String]) {
        if model.needsPermission {
            model.fallbackTitles = titles
        } else {
            model.windows = windows
            model.loading = false
        }
        resizeAndPlace(tile: lastTile)
    }

    /// Closes one window from the popup, then refreshes the thumbnails (the popup closes with the last window).
    func closeWindow(_ window: AppWindow) {
        guard let app = model.app else { return }
        Task.detached(priority: .userInitiated) { WindowCatalog.close(window, of: app) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.reload() }
    }

    private func reload() {
        guard panel.isVisible, let app = model.app else { return }
        generation += 1
        let mine = generation
        Task { @MainActor in
            let windows = await WindowCatalog.windows(for: app.processIdentifier, fresh: true)
            guard mine == self.generation else { return }
            if windows.isEmpty { self.hideNow(); return }
            self.model.windows = windows
            self.resizeAndPlace(tile: self.lastTile)
        }
    }

    private func scheduleHide() {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.overTile, !self.overPreview else { return }
            self.hideNow()
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func show(_ app: NSRunningApplication, tile: CGRect) {
        guard overTile, PanelController.shared.isVisible, NSEvent.pressedMouseButtons == 0 else { return }
        lastTile = tile
        model.app = app
        model.needsPermission = !Permissions.screenRecording
        // Already loaded (the usual case): shown complete at once, with no loading step and no second resize.
        if let loaded, loaded.pid == app.processIdentifier {
            model.windows = loaded.windows
            model.fallbackTitles = loaded.titles
            model.loading = false
        } else {
            model.windows = []
            model.fallbackTitles = []
            model.loading = !model.needsPermission
        }
        resizeAndPlace(tile: tile)
        panel.orderFrontRegardless()

        // Pressing the mouse anywhere but on the popup itself (to click the tile, or to start dragging it) dismisses it,
        // so it never sits in the way of a drag.
        if mouseMonitor == nil {
            mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .leftMouseDragged]) { [weak self] event in
                if let self, event.window !== self.panel { self.hideNow() }
                return event
            }
        }
    }

    private func resizeAndPlace(tile: CGRect) {
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        let main = PanelController.shared.frame
        let tileTop = main.maxY - tile.minY, tileBottom = main.maxY - tile.maxY
        let screen = NSScreen.screens.first { NSMouseInRect(NSPoint(x: main.midX, y: main.midY), $0.frame, false) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? main
        var x = main.minX + tile.midX - size.width / 2
        x = max(visible.minX + 8, min(x, visible.maxX - size.width - 8))
        var y = tileTop + 6
        if y + size.height > visible.maxY { y = tileBottom - 6 - size.height }
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        panel.invalidateShadow()          // the shadow follows the rounded shape at its new size
    }
}

struct WindowPreviewView: View {
    @ObservedObject var model: WindowPreviewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let app = model.app {
                Text(headline(app)).font(.system(size: 12, weight: .semibold))
            }
            if model.needsPermission {
                permissionHint
            } else if model.loading {
                ProgressView().controlSize(.small).frame(width: 180, height: 60)
            } else if model.windows.isEmpty {
                Text("No open windows").font(.system(size: 11)).foregroundStyle(.secondary)
            } else {
                // Spaces sit side by side; within a Space, thumbnails run left to right.
                HStack(alignment: .top, spacing: 20) {
                    ForEach(groups.indices, id: \.self) { g in
                        VStack(alignment: .leading, spacing: 8) {
                            if groups.count > 1 {
                                Text("Space \(groups[g].space)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(groups[g].rows.indices, id: \.self) { r in
                                HStack(alignment: .top, spacing: 10) {
                                    ForEach(groups[g].rows[r]) { WindowThumbnail(window: $0, app: model.app) }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .fixedSize()
        .onHover { WindowPreviewController.shared.previewHover($0) }
    }

    /// Windows grouped by Space (already in order), three thumbnails to a row. Space titles show only when the
    /// app has windows on more than one Space.
    private var groups: [(space: Int, rows: [[AppWindow]])] {
        var order: [Int] = []
        for w in model.windows where !order.contains(w.spaceNumber) { order.append(w.spaceNumber) }
        let perRow = order.count > 1 ? 2 : 3          // narrower columns when Spaces sit side by side
        return order.map { space in
            let windows = model.windows.filter { $0.spaceNumber == space }
            let rows = stride(from: 0, to: windows.count, by: perRow).map { Array(windows[$0..<min($0 + perRow, windows.count)]) }
            return (space, rows)
        }
    }

    private func headline(_ app: NSRunningApplication) -> String {
        let name = app.localizedName ?? "App"
        if model.needsPermission || model.loading { return name }
        let n = model.windows.count
        return n == 1 ? "\(name) · 1 window" : "\(name) · \(n) windows"
    }

    private var permissionHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Allow Screen Recording to see window previews.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            ForEach(model.fallbackTitles, id: \.self) { Text($0).font(.system(size: 11)).lineLimit(1) }
            HStack {
                Button("Open Settings") { Permissions.openSettings("Privacy_ScreenCapture") }
                Button("Open app") {
                    if let app = model.app { PanelController.shared.hide(restoreFocus: false); app.activate(options: []) }
                    WindowPreviewController.shared.hideNow()
                }
            }
            .controlSize(.small)
        }
        .frame(width: 240, alignment: .leading)
    }
}

struct WindowThumbnail: View {
    let window: AppWindow
    let app: NSRunningApplication?
    @State private var hovering = false

    var body: some View {
        let size = WindowCatalog.thumbnailSize
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06))
                if let image = window.image {
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).padding(2)
                }
            }
            .frame(width: size.width, height: size.height)
            .overlay(RoundedRectangle(cornerRadius: 6)
                .stroke(hovering ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: hovering ? 2 : 0.5))
            .overlay(alignment: .topLeading) {
                if window.canClose { CloseCross { WindowPreviewController.shared.closeWindow(window) } }
            }
            Text(window.title.isEmpty ? (app?.localizedName ?? "Window") : window.title)
                .font(.system(size: 11)).lineLimit(1).frame(width: size.width, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { if let app { WindowCatalog.focus(window, of: app) } }
    }
}

/// The small cross in a thumbnail's corner: closes that one window.
private struct CloseCross: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(hovering ? Color.red : Color.black.opacity(0.55)))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .padding(5)
        .help("Close this window")
    }
}

/// Which running apps have windows that "Close Windows" can close. Finding out means asking each app over
/// Accessibility and waiting for its answer, which took about 300 ms for a dozen apps (and a busy app can take far
/// longer). So it is asked in the background, when the panel opens and when a running app is pointed at, and the
/// tiles' menus read the last answer.
final class ClosableWindows: ObservableObject {
    static let shared = ClosableWindows()
    @Published private(set) var pids: Set<pid_t> = []
    private let queue = DispatchQueue(label: "HomePad.closable-windows", qos: .userInitiated)
    private var running = false
    private var lastRun = 0.0

    /// At most every few seconds: pointing along the running apps asked every app about its windows each time.
    func refresh() {
        guard CACurrentMediaTime() - lastRun > 3 else { return }
        guard !running else { return }
        running = true
        lastRun = CACurrentMediaTime()
        let candidates = RunningApps.shared.apps.map(\.processIdentifier)
        queue.async {
            let found = Set(candidates.filter { WindowCatalog.closableWindowCount(for: $0) > 0 })
            DispatchQueue.main.async {
                self.running = false
                if found != self.pids { self.pids = found }
            }
        }
    }
}

/// What a running app's right-click menu lists beyond the basics, like the Dock's: its windows (the one in front
/// checked) and the "New …" commands from its File menu (New Tab, New Window, New Private Window in a browser).
/// The Dock gets an app's own menu through a private channel, so the File menu stands in for it. Reading either means
/// asking the app over Accessibility, so it is done in the background when the pointer reaches the tile, and the
/// menu, which SwiftUI builds along with the tile, shows what was last read.
final class AppMenus: ObservableObject {
    struct Window: Identifiable {
        let id: CGWindowID
        let title: String
        let frame: CGRect
        let onOtherSpace: Bool
        let isMain: Bool
    }
    struct Command: Identifiable {
        let title: String
        let element: AXUIElement
        var id: String { title }
    }
    struct Info {
        var windows: [Window] = []
        var commands: [Command] = []
    }

    static let shared = AppMenus()
    @Published private(set) var info: [pid_t: Info] = [:]
    private var lastRead: [pid_t: Double] = [:]
    private let queue = DispatchQueue(label: "HomePad.app-menus", qos: .userInitiated)

    /// At most every two seconds per app.
    func refresh(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard CACurrentMediaTime() - (lastRead[pid] ?? 0) > 2 else { return }
        lastRead[pid] = CACurrentMediaTime()
        let name = app.localizedName ?? "Window"
        queue.async {
            let found = Self.read(pid: pid, appName: name)
            DispatchQueue.main.async { self.info[pid] = found }
        }
    }

    private static func read(pid: pid_t, appName: String) -> Info {
        let trusted = Permissions.accessibility
        let axApp = AXUIElementCreateApplication(pid)
        // The window in front: on the Space showing, with the main window's title and place (windows on other Spaces
        // often share both size and position, so the title is what tells them apart).
        let mainWindow = trusted ? element(axApp, kAXMainWindowAttribute) : nil
        let mainFrame = mainWindow.flatMap(frame), mainTitle = mainWindow.flatMap { string($0, kAXTitleAttribute) }
        var marked = false
        let windows = WindowCatalog.realWindows(for: pid, askingApp: trusted)
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            .map { w -> Window in
                var isMain = false
                if !marked, !w.onOtherSpace, let mainFrame,
                   abs(mainFrame.minX - w.frame.minX) < 4, abs(mainFrame.minY - w.frame.minY) < 4, abs(mainFrame.width - w.frame.width) < 4,
                   mainTitle == nil || w.title.isEmpty || mainTitle == w.title {
                    isMain = true
                    marked = true
                }
                return Window(id: w.id, title: w.title.isEmpty ? appName : w.title, frame: w.frame, onOtherSpace: w.onOtherSpace, isMain: isMain)
            }
        return Info(windows: windows, commands: trusted ? newCommands(axApp) : [])
    }

    /// The enabled "New …" items of the app's File menu (titled File, or else the third menu: after the Apple menu and
    /// the app's own).
    private static func newCommands(_ app: AXUIElement) -> [Command] {
        guard let bar = element(app, kAXMenuBarAttribute) else { return [] }
        let menus = children(bar)
        guard let file = menus.first(where: { string($0, kAXTitleAttribute) == "File" }) ?? (menus.count > 2 ? menus[2] : nil),
              let fileMenu = children(file).first else { return [] }
        return children(fileMenu).compactMap { item in
            guard let title = string(item, kAXTitleAttribute), title == "New" || title.hasPrefix("New "),
                  bool(item, kAXEnabledAttribute) != false, children(item).isEmpty else { return nil }
            return Command(title: title.replacingOccurrences(of: "…", with: "").trimmingCharacters(in: .whitespaces), element: item)
        }
    }

    private static func element(_ e: AXUIElement, _ attribute: String) -> AXUIElement? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(e, attribute as CFString, &ref) == .success, let ref,
              CFGetTypeID(ref) == AXUIElementGetTypeID() else { return nil }
        return (ref as! AXUIElement)
    }

    private static func children(_ e: AXUIElement) -> [AXUIElement] {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(e, kAXChildrenAttribute as CFString, &ref)
        return ref as? [AXUIElement] ?? []
    }

    private static func string(_ e: AXUIElement, _ attribute: String) -> String? {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(e, attribute as CFString, &ref)
        return ref as? String
    }

    private static func bool(_ e: AXUIElement, _ attribute: String) -> Bool? {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(e, attribute as CFString, &ref)
        return ref as? Bool
    }

    private static func frame(_ e: AXUIElement) -> CGRect? {
        var pos: CFTypeRef?, size: CFTypeRef?
        AXUIElementCopyAttributeValue(e, kAXPositionAttribute as CFString, &pos)
        AXUIElementCopyAttributeValue(e, kAXSizeAttribute as CFString, &size)
        var p = CGPoint.zero, s = CGSize.zero
        guard let pos, let size, AXValueGetValue(pos as! AXValue, .cgPoint, &p), AXValueGetValue(size as! AXValue, .cgSize, &s) else { return nil }
        return CGRect(origin: p, size: s)
    }

    /// Runs one of the app's "New …" commands, then brings the app forward to show what it made.
    static func run(_ command: Command, of app: NSRunningApplication) {
        PanelController.shared.hide(restoreFocus: false)
        DispatchQueue.global(qos: .userInteractive).async {
            AXUIElementPerformAction(command.element, kAXPressAction as CFString)
            DispatchQueue.main.async { app.activate(options: []) }
        }
    }
}
