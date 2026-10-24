import AppKit
import SwiftUI
import ScreenCaptureKit
import ApplicationServices

// MARK: - Permissions

enum Permissions {
    static var screenRecording: Bool { CGPreflightScreenCaptureAccess() }
    static var accessibility: Bool { AXIsProcessTrusted() }

    /// Our panels float above ordinary windows, which would hide the system's permission dialog behind them.
    private static func clearFloatingWindows() {
        PanelController.shared.hide(restoreFocus: false)
        WindowPreviewController.shared.hideNow()
    }

    static func requestScreenRecording() {
        guard !screenRecording else { return }      // already allowed: never ask again
        clearFloatingWindows()
        _ = CGRequestScreenCaptureAccess()
    }

    static func requestAccessibility() {
        guard !accessibility else { return }        // already allowed: never ask again
        clearFloatingWindows()
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    static func openSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
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
}

enum WindowCatalog {
    static let thumbnailSize = CGSize(width: 180, height: 112)

    /// Lists an app's windows with thumbnails. Needs Screen Recording permission.
    static func windows(for pid: pid_t) async -> [AppWindow] {
        guard Permissions.screenRecording,
              let content = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
        else { return [] }

        let real = Dictionary(uniqueKeysWithValues: realWindows(for: pid).map { ($0.id, $0) })
        let wins = content.windows.filter { $0.owningApplication?.processID == pid && real[$0.windowID] != nil }
        var result: [AppWindow] = []
        for w in wins {
            result.append(AppWindow(id: w.windowID, title: w.title ?? "", frame: w.frame, image: await thumbnail(of: w),
                                    onOtherSpace: real[w.windowID]?.onOtherSpace ?? false))
        }
        return result.map { window in
            var w = window
            w.canClose = !Permissions.accessibility || closeButton(for: window, pid: pid) != nil
            return w
        }
    }

    private static func thumbnail(of window: SCWindow) async -> NSImage? {
        guard #available(macOS 14.0, *) else { return nil }   // SCScreenshotManager needs macOS 14
        let config = SCStreamConfiguration()
        let scale = min(thumbnailSize.width * 2 / window.frame.width, thumbnailSize.height * 2 / window.frame.height)
        config.width = max(1, Int(window.frame.width * scale))
        config.height = max(1, Int(window.frame.height * scale))
        config.showsCursor = false
        let filter = SCContentFilter(desktopIndependentWindow: window)
        guard let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width / 2, height: image.height / 2))
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
    }

    /// The windows a person would call windows: visible ones, minimised ones, and ones on other Spaces. Apps also
    /// keep many hidden helper windows (DaVinci Resolve has dozens). Those belong to no Space, which is how
    /// they're told apart from a real window on another desktop.
    /// Needs no permission, so it works before Screen Recording or Accessibility are allowed.
    static func realWindows(for pid: pid_t) -> [RealWindow] {
        let minimised = axWindows(pid)
            .filter { axBool($0, kAXMinimizedAttribute) == true }
            .compactMap(axFrame)
        let infos = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
        let activeSpace = SkyLight.activeSpace
        return infos.compactMap { info in
            guard (info[kCGWindowOwnerPID as String] as? Int32) == pid,
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let number = info[kCGWindowNumber as String] as? CGWindowID,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds),
                  rect.width > 80, rect.height > 60 else { return nil }
            let onScreen = (info[kCGWindowIsOnscreen as String] as? Bool) ?? ((info[kCGWindowIsOnscreen as String] as? Int) == 1)
            let spaces = SkyLight.spaces(of: number)
            let otherSpace = activeSpace.map { active in !spaces.isEmpty && !spaces.contains(active) } ?? false
            guard onScreen || otherSpace || minimised.contains(where: near(rect)) else { return nil }
            return RealWindow(id: number, frame: rect, onOtherSpace: otherSpace)
        }
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

    static func focus(_ window: AppWindow, of app: NSRunningApplication) {
        PanelController.shared.hide(restoreFocus: false)
        WindowPreviewController.shared.hideNow()
        // A window on another Space can't be reached through Accessibility. Activating the app makes macOS
        // switch to a Space where it has windows; naming the window first points it at this one.
        if window.onOtherSpace {
            SkyLight.focus(window: window.id, pid: app.processIdentifier)
            app.activate(options: [.activateAllWindows])
            return
        }
        guard Permissions.accessibility else {
            Permissions.requestAccessibility()
            app.activate(options: [.activateAllWindows])
            return
        }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        if let match = axWindow(for: window, pid: app.processIdentifier) {
            AXUIElementSetAttributeValue(match, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            AXUIElementPerformAction(match, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(axApp, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        }
        app.activate(options: [])
    }

    /// Closes one specific window by pressing its close button. Needs the Accessibility permission.
    @discardableResult
    static func close(_ window: AppWindow, of app: NSRunningApplication) -> Bool {
        guard Permissions.accessibility else { Permissions.requestAccessibility(); return false }
        guard let button = closeButton(for: window, pid: app.processIdentifier) else { return false }
        return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
    }

    private static func closeButton(for window: AppWindow, pid: pid_t) -> AXUIElement? {
        axWindow(for: window, pid: pid).flatMap(closeButton(of:))
    }

    /// The Accessibility element for a window from the window list: by title and position, then position, then title.
    private static func axWindow(for window: AppWindow, pid: pid_t) -> AXUIElement? {
        let candidates = axWindows(pid)
        return candidates.first { axString($0, kAXTitleAttribute) == window.title && axFrame($0).map(near(window.frame)) == true }
            ?? candidates.first { axFrame($0).map(near(window.frame)) == true }
            ?? candidates.first { !window.title.isEmpty && axString($0, kAXTitleAttribute) == window.title }
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
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 12
        effect.layer?.masksToBounds = true
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
        if over, let app {
            hideWork?.cancel()
            if panel.isVisible, model.app?.processIdentifier == app.processIdentifier { return }
            showWork?.cancel()
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
        showWork?.cancel()
        hideWork?.cancel()
        generation += 1
        overTile = false
        overPreview = false
        panel.orderOut(nil)
    }

    /// Closes one window from the popup, then refreshes the thumbnails (the popup closes with the last window).
    func closeWindow(_ window: AppWindow) {
        guard let app = model.app else { return }
        WindowCatalog.close(window, of: app)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.reload() }
    }

    private func reload() {
        guard panel.isVisible, let app = model.app else { return }
        generation += 1
        let mine = generation
        Task { @MainActor in
            let windows = await WindowCatalog.windows(for: app.processIdentifier)
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
        guard overTile, PanelController.shared.isVisible else { return }
        generation += 1
        let mine = generation
        lastTile = tile
        model.app = app
        model.windows = []
        model.fallbackTitles = []
        model.needsPermission = !Permissions.screenRecording
        model.loading = !model.needsPermission
        if model.needsPermission {
            model.fallbackTitles = WindowCatalog.titles(for: app.processIdentifier)
        }
        resizeAndPlace(tile: tile)
        panel.orderFrontRegardless()

        guard !model.needsPermission else { return }
        Task { @MainActor in
            let windows = await WindowCatalog.windows(for: app.processIdentifier)
            guard mine == self.generation else { return }
            self.model.windows = windows
            self.model.loading = false
            self.resizeAndPlace(tile: tile)
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
                ForEach(rows.indices, id: \.self) { r in
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(rows[r]) { WindowThumbnail(window: $0, app: model.app) }
                    }
                }
            }
        }
        .padding(12)
        .fixedSize()
        .onHover { WindowPreviewController.shared.previewHover($0) }
    }

    private var rows: [[AppWindow]] {
        stride(from: 0, to: model.windows.count, by: 3).map { Array(model.windows[$0..<min($0 + 3, model.windows.count)]) }
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
