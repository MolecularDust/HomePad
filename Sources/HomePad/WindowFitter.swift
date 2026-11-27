import AppKit
import ApplicationServices

/// Taskbar mode: keeps windows above the taskbar, as Windows does for maximized windows. macOS lets only the Dock keep
/// windows off part of the screen (and the Dock shows its labels wherever the pointer passes over its icons, even
/// under the taskbar, so it can't stay there). So, with Accessibility, a window that is opened, resized, maximized or
/// tiled so that it reaches under the taskbar is made shorter to end at the taskbar's top (moved up instead if it
/// would get too short). A window only dragged there is left alone, as on Windows, and full-screen windows too.
/// All windows are fitted once when the taskbar appears.
final class WindowFitter {
    static let shared = WindowFitter()

    private var observers: [pid_t: AXObserver] = [:]
    private var workspaceObservers: [NSObjectProtocol] = []
    private var waitingForMouseUp: Set<CFHashCode> = []
    private var running = false

    func start() {
        guard !running, AXIsProcessTrusted() else { return }
        running = true
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular { watch(app) }
        let nc = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil,
                                                 queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            // Apps often become regular apps a moment after launching (see RunningApps).
            for delay in [0.0, 1.0, 3.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { self?.watch(app) }
            }
        })
        workspaceObservers.append(nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil,
                                                 queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.unwatch(app.processIdentifier)
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.fitAll() }
    }

    func stop() {
        guard running else { return }
        running = false
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        workspaceObservers = []
        for pid in Array(observers.keys) { unwatch(pid) }
    }

    // MARK: Watching apps

    private static let notifications = [kAXWindowCreatedNotification, kAXWindowResizedNotification]

    private func watch(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard running, app.activationPolicy == .regular, observers[pid] == nil,
              pid != ProcessInfo.processInfo.processIdentifier else { return }
        var observer: AXObserver?
        guard AXObserverCreate(pid, { _, element, notification, _ in
            WindowFitter.shared.changed(element, notification as String)
        }, &observer) == .success, let observer else { return }
        let element = AXUIElementCreateApplication(pid)
        for name in Self.notifications { AXObserverAddNotification(observer, element, name as CFString, nil) }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        observers[pid] = observer
        for window in windows(of: pid) { fit(window) }
    }

    private func unwatch(_ pid: pid_t) {
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
    }

    private func changed(_ element: AXUIElement, _ notification: String) {
        guard !ShowDesktop.shared.isBusy else { return }
        // A new window: fit once it has settled into its size (apps often size it right after creating it).
        if notification == kAXWindowCreatedNotification as String {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.fit(element) }
            return
        }
        fitWhenMouseIsUp(element)
    }

    /// While you're dragging a window's edge, it's left alone; it's fitted when you let go.
    private func fitWhenMouseIsUp(_ window: AXUIElement) {
        guard NSEvent.pressedMouseButtons & 1 != 0 else { fit(window); return }
        let key = CFHash(window)
        guard waitingForMouseUp.insert(key).inserted else { return }
        func check() {
            if NSEvent.pressedMouseButtons & 1 != 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: check)
            } else {
                waitingForMouseUp.remove(key)
                fit(window)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: check)
    }

    /// All windows again, after the taskbar's auto-hide was switched.
    func refit() { fitAll() }

    private func fitAll() {
        for pid in observers.keys { for window in windows(of: pid) { fit(window) } }
    }

    private func windows(of pid: pid_t) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXWindowsAttribute as CFString, &value)
                == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }

    // MARK: Fitting

    /// The lowest a window may reach, in Accessibility's coordinates (from the top left of the main screen).
    private var limit: CGFloat? {
        // An auto-hidden taskbar leaves the whole screen to the windows.
        guard running, !Taskbar.autoHides, let taskbar = Taskbar.shared.frame, let main = NSScreen.screens.first else { return nil }
        return main.frame.maxY - taskbar.maxY
    }

    private func fit(_ window: AXUIElement) {
        guard !ShowDesktop.shared.isBusy, let limit, let main = NSScreen.screens.first,
              attribute(window, kAXSubroleAttribute) as? String == kAXStandardWindowSubrole as String,
              attribute(window, "AXFullScreen") as? Bool != true,
              attribute(window, kAXMinimizedAttribute) as? Bool != true,
              var origin = point(window), var size = size(window) else { return }
        // Only windows on the screen with the taskbar, reaching below its top.
        guard origin.x < main.frame.maxX, origin.x + size.width > main.frame.minX,
              origin.y < limit, origin.y + size.height > limit + 1 else { return }
        let menuBar = main.frame.maxY - main.visibleFrame.maxY
        let shorter = limit - origin.y
        if shorter >= 200 {
            size.height = shorter
        } else {
            // Too short that way: up, as far as the menu bar, and shorter only if it still doesn't fit.
            origin.y = max(menuBar, limit - size.height)
            size.height = min(size.height, limit - origin.y)
            set(window, kAXPositionAttribute, origin)
        }
        set(window, kAXSizeAttribute, size)
    }

    // MARK: Accessibility helpers

    private func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    private func point(_ element: AXUIElement) -> CGPoint? {
        guard let value = attribute(element, kAXPositionAttribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value as! AXValue, .cgPoint, &point) ? point : nil
    }

    private func size(_ element: AXUIElement) -> CGSize? {
        guard let value = attribute(element, kAXSizeAttribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value as! AXValue, .cgSize, &size) ? size : nil
    }

    private func set(_ element: AXUIElement, _ name: String, _ point: CGPoint) {
        var point = point
        if let value = AXValueCreate(.cgPoint, &point) { AXUIElementSetAttributeValue(element, name as CFString, value) }
    }

    private func set(_ element: AXUIElement, _ name: String, _ size: CGSize) {
        var size = size
        if let value = AXValueCreate(.cgSize, &size) { AXUIElementSetAttributeValue(element, name as CFString, value) }
    }
}
