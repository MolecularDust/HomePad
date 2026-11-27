import AppKit
import ApplicationServices
import Combine
import os

/// Persistently minimizes this desktop's windows and restores only those windows on the next click. Prepare the
/// entire batch first, then keep a screen cover up until the real states have settled. The Dock serializes animations
/// even for concurrent requests, so concurrency alone cannot make the visible result atomic.
// isBusy is used on the main thread; restore lists are confined to queue. Accessibility workers only use snapshots.
final class ShowDesktop: ObservableObject, @unchecked Sendable {
    static let shared = ShowDesktop()
    @Published private(set) var isBusy = false
    private let queue = DispatchQueue(label: "local.mike.HomePad.show-desktop", qos: .userInitiated)

    private struct Window {
        var id: CGWindowID
        let pid: pid_t
        // HomePad's own windows are handled on the main thread. AX calls to our own process execute AppKit directly
        // on the calling thread, so sending those from the background would crash.
        var element: AXUIElement?
        var canMinimize = true
        var frame: CGRect?
        let originalFrame: CGRect?
        var title: String?
        var localWindow: NSWindow?
        let identity = UUID()
    }
    private struct HiddenApplication {
        let pid: pid_t
        let element: AXUIElement
    }
    private struct Focus {
        let pid: pid_t
        let windowID: CGWindowID?
    }
    private struct Batch {
        let windows: [Window]
        let hidden: [HiddenApplication]
        let scene: DesktopTransition.Scene?
        let layout: [Window]
        let focus: Focus?

        init(windows: [Window], hidden: [HiddenApplication], scene: DesktopTransition.Scene?, layout: [Window]? = nil, focus: Focus? = nil) {
            self.windows = windows
            self.hidden = hidden
            self.scene = scene
            self.layout = layout ?? windows
            self.focus = focus
        }
    }
    // Only the coordinator queue accesses these lists. Each Space keeps its own batch.
    private var minimized: [[Int]: Batch] = [:]
    private let log = Logger(subsystem: "local.mike.HomePad", category: "show-desktop")

    func toggle() {
        guard !isBusy else { return }
        guard Permissions.accessibility else { Permissions.requestAccessibility(); return }
        guard Permissions.screenRecording else { Permissions.requestScreenRecording(); return }
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let ownKeyWindow = NSApp.keyWindow.flatMap { CGWindowID(exactly: $0.windowNumber) }
        PanelController.shared.hide(restoreFocus: false)
        TaskbarFlyout.shared.close()
        WindowPreviewController.shared.hideNow()
        let desktop = SkyLight.visibleSpaces
        // Include covered windows, but exclude hidden apps and other Spaces. Window numbers need no Screen Recording
        // permission and work even when macOS withholds window titles.
        let visible = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        isBusy = true
        Task { @MainActor in
            // Discover targets before drawing the minimize cover, so that cover can already show the desktop.
            // The next click presents the saved window scene while restoring the live windows underneath.
            let (windows, scene, focus): ([Window]?, DesktopTransition.Scene?, Focus?) = await withCheckedContinuation { continuation in
                self.queue.async {
                    let completedRetry = self.pruneCompletedRetry(on: desktop)
                    if let batch = self.minimized[desktop], !batch.windows.isEmpty || !batch.hidden.isEmpty {
                        continuation.resume(returning: (nil, batch.scene, batch.focus))
                    } else {
                        continuation.resume(returning: (Self.prepare(completedRetry ? Self.visibleWindows() : visible, on: desktop), nil,
                                                        Self.captureFocus(pid: frontPID, ownWindowID: ownKeyWindow)))
                    }
                }
            }
            guard SkyLight.visibleSpaces == desktop else { self.isBusy = false; return }
            let transition = DesktopTransition()
            let originalScene: DesktopTransition.Scene?
            do { originalScene = try await transition.begin(excludingWindowIDs: Set(windows?.map(\.id) ?? []), restoring: scene) }
            catch {
                self.log.error("Could not prepare desktop transition: \(error.localizedDescription, privacy: .public)")
                self.isBusy = false
                if !Permissions.screenRecording { Permissions.requestScreenRecording() }
                return
            }
            self.queue.async {
                defer {
                    Task { @MainActor in
                        await transition.finishAfterRendering()
                        self.isBusy = false
                    }
                }
                guard SkyLight.visibleSpaces == desktop else { return }
                let key = desktop
                if let batch = self.minimized.removeValue(forKey: key), !batch.windows.isEmpty || !batch.hidden.isEmpty {
                    self.log.notice("Restoring desktop batch: \(batch.windows.count) windows; \(batch.hidden.count) hidden apps")
                    self.restore(batch, on: desktop)
                } else {
                    let windows = windows ?? []
                    // Remember stable IDs before making any changes. An app can apply the request but time out
                    // replying, so an Accessibility acknowledgement must never decide whether we remember it.
                    if !windows.isEmpty { self.minimized[key] = Batch(windows: windows, hidden: [], scene: originalScene, focus: focus) }
                    self.log.notice("Saving desktop batch: \(windows.count) windows")
                    let normal = windows.filter(\.canMinimize)
                    let changed = Self.change(normal, minimized: true, on: desktop)
                    // Non-minimizable windows (such as a document's modal dialog) still have to leave the desktop.
                    // Remember the affected app explicitly so the restore click reverses this fallback too.
                    // A custom accessibility setter may report a minimized state without removing the surface.
                    // Give a completed frame a chance to flush, then require the window to have actually left.
                    Thread.sleep(forTimeInterval: 0.04)
                    let stillVisible = Self.visibleWindows()
                    let unsupported = windows.filter { !$0.canMinimize }
                        + zip(normal, changed).filter { !$0.1 || Self.isVisible($0.0, in: stillVisible) }.map { $0.0 }
                    Self.orderLocalWindows(unsupported, visible: false)
                    let hidden = Self.hideApplications(Set(unsupported.map(\.pid)))
                    if !windows.isEmpty || !hidden.isEmpty { self.minimized[key] = Batch(windows: windows, hidden: hidden, scene: originalScene, focus: focus) }
                    // AXHidden can change before the compositor removes the app's last surface. Keep the cover up
                    // through that final frame too, rather than revealing a window that is still disappearing.
                    let deadline = Date().addingTimeInterval(2)
                    while SkyLight.visibleSpaces == desktop, Date() < deadline {
                        let visible = Self.visibleWindows()
                        if !windows.contains(where: { Self.isVisible($0, in: visible) }) { break }
                        Thread.sleep(forTimeInterval: 0.01)
                    }
                }
            }
        }
    }

    private func restore(_ batch: Batch, on desktop: [Int]) {
        // Apps may replace Accessibility objects when a window is minimized. Rebind by process + window ID and
        // attempt restoration even if a stale object claims the window is already restored or no longer exists.
        Self.unhideApplications(batch.hidden)
        Self.orderLocalWindows(batch.windows.filter { !$0.canMinimize }, visible: true)
        let targets = Self.refresh(batch.windows.filter(\.canMinimize))
        let restored = Self.change(targets, minimized: false, on: desktop)
        var remaining = zip(targets, restored).filter { !$0.1 }.map { $0.0 }
        var other = Self.refresh(batch.windows.filter { !$0.canMinimize })
        let revealDeadline = Date().addingTimeInterval(2)
        while !other.isEmpty, SkyLight.visibleSpaces == desktop, Date() < revealDeadline {
            let visible = Self.visibleWindows()
            other = other.filter { !Self.isVisible($0, in: visible) }
            if !other.isEmpty { Thread.sleep(forTimeInterval: 0.01); other = Self.refresh(other) }
        }
        remaining += other
        Self.restoreLayout(Self.refresh(batch.layout), on: desktop)
        if SkyLight.visibleSpaces == desktop { Self.restoreFocus(batch.focus, layout: batch.layout) }
        // An unhide acknowledgement is only an early snapshot. Reconcile after the windows, layout and focus have
        // settled; otherwise an app that has already reappeared leaves an empty retry that consumes the next click.
        let pending = Self.pendingRestore(windows: remaining, hidden: batch.hidden, layout: batch.layout)
        remaining = pending.windows
        let hiddenToRetry = pending.hidden
        if !remaining.isEmpty || !hiddenToRetry.isEmpty {
            // A retry concerns only the remaining windows, so release the complete batch's old scene.
            minimized[desktop] = Batch(windows: remaining, hidden: hiddenToRetry, scene: nil, layout: batch.layout, focus: batch.focus)
        }
        log.notice("Desktop restore visibility check finished; pending: \(remaining.count); hidden apps: \(hiddenToRetry.count)")
    }

    private func pruneCompletedRetry(on desktop: [Int]) -> Bool {
        // A real failure may recover after the previous click finished. Prune only retry batches, so normal
        // restore clicks still present their cached scene immediately without querying every minimized window.
        guard let batch = minimized[desktop], batch.scene == nil else { return false }
        let pending = Self.pendingRestore(windows: batch.windows, hidden: batch.hidden, layout: batch.layout)
        if pending.windows.isEmpty && pending.hidden.isEmpty {
            minimized.removeValue(forKey: desktop)
            return true
        } else {
            minimized[desktop] = Batch(windows: pending.windows, hidden: pending.hidden, scene: nil,
                                      layout: batch.layout, focus: batch.focus)
            return false
        }
    }

    private static func pendingRestore(windows: [Window], hidden: [HiddenApplication], layout: [Window])
        -> (windows: [Window], hidden: [HiddenApplication]) {
        let visible = visibleWindows()
        let remaining = refresh(windows).filter { !isVisible($0, in: visible) || state($0).value == true }
        let pendingPIDs = Set(remaining.map(\.pid))
        let visiblePIDs = Set(layout.filter { isVisible($0, in: visible) }.map(\.pid))
        let stillHidden = parallel(hidden) { app -> Bool in
            if pendingPIDs.contains(app.pid) { return true }
            if visiblePIDs.contains(app.pid) { return false }
            return NSRunningApplication(processIdentifier: app.pid)?.isHidden == true
        }
        return (remaining, zip(hidden, stillHidden).filter { $0.1 }.map { $0.0 })
    }

    private static func captureFocus(pid: pid_t?, ownWindowID: CGWindowID?) -> Focus? {
        guard let pid else { return nil }
        if pid == ProcessInfo.processInfo.processIdentifier { return Focus(pid: pid, windowID: ownWindowID) }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.5)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value)
        var id: CGWindowID?
        if result == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() {
            id = RemoteAX.windowID(of: value as! AXUIElement)
        }
        return Focus(pid: pid, windowID: id)
    }

    private static func restoreFocus(_ focus: Focus?, layout: [Window]) {
        guard let focus, NSRunningApplication(processIdentifier: focus.pid) != nil else { return }
        let original = layout.first { $0.pid == focus.pid && $0.id == focus.windowID }
        let id = original.flatMap { refresh([$0]).first?.id } ?? focus.windowID
        let visible = visibleWindows()
        if let id, visible.contains(where: { $0[kCGWindowOwnerPID as String] as? pid_t == focus.pid && $0[kCGWindowNumber as String] as? CGWindowID == id }) {
            SkyLight.raisePreservingOthers(window: id, pid: focus.pid)
        } else {
            // A desktop click or a closed focused window must not revive a previously minimized window.
            SkyLight.activatePreservingWindowOrder(pid: focus.pid)
        }
    }

    private static func prepare(_ visible: [[String: Any]], on desktop: [Int]) -> [Window] {
        var idsByPID: [pid_t: Set<CGWindowID>] = [:]
        var order: [CGWindowID: Int] = [:]
        for (index, info) in visible.enumerated() {
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  let id = info[kCGWindowNumber as String] as? CGWindowID,
                  let level = info[kCGWindowLayer as String] as? Int, (0...8).contains(level),
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0 else { continue }
            idsByPID[pid, default: []].insert(id)
            order[id] = index
        }
        let candidates = parallel(Array(idsByPID)) { entry -> [Window] in
            guard SkyLight.visibleSpaces == desktop else { return [] }
            let (pid, ids) = entry
            if pid == ProcessInfo.processInfo.processIdentifier {
                return DispatchQueue.main.sync {
                    NSApp.windows.compactMap { window in
                        // Hidden or deferred AppKit windows can have windowNumber == -1. They have no window-server
                        // ID yet; an unchecked unsigned conversion traps before any other filter can reject them.
                        guard let id = CGWindowID(exactly: window.windowNumber), ids.contains(id),
                              (window.isMiniaturizable || window.styleMask.contains(.titled)), !window.isMiniaturized,
                              !window.styleMask.contains(.fullScreen) else { return nil }
                        return Window(id: id, pid: pid, element: nil, canMinimize: window.isMiniaturizable,
                                      originalFrame: window.frame, localWindow: window)
                    }
                }
            }
            let app = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(app, 0.5)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
                  let windows = value as? [AXUIElement] else { return [] }
            // Geometry fallback must obey the same layer/alpha filters as exact IDs. Finder exposes its desktop as
            // an AX window with no usable ID; matching it to the wallpaper surface creates a phantom restore target.
            let surfaces = visible.filter {
                guard $0[kCGWindowOwnerPID as String] as? pid_t == pid,
                      let id = $0[kCGWindowNumber as String] as? CGWindowID else { return false }
                return ids.contains(id)
            }
            return windows.compactMap { element in
                let frame = frame(element)
                let reportedID = RemoteAX.windowID(of: element)
                let matchedID = surfaces.first { info in
                    guard let frame, let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                          let rect = CGRect(dictionaryRepresentation: bounds) else { return false }
                    return near(frame, rect)
                }?[kCGWindowNumber as String] as? CGWindowID
                guard let id = reportedID.flatMap({ ids.contains($0) ? $0 : nil }) ?? matchedID else { return nil }
                AXUIElementSetMessagingTimeout(element, 1)
                var settable = DarwinBoolean(false)
                guard bool(element, kAXMinimizedAttribute) != true,
                      bool(element, "AXFullScreen") != true else { return nil }
                let supported = AXUIElementIsAttributeSettable(element, kAXMinimizedAttribute as CFString, &settable) == .success && settable.boolValue
                return Window(id: id, pid: pid, element: element, canMinimize: supported,
                              frame: frame, originalFrame: frame, title: string(element, kAXTitleAttribute))
            }
        }.flatMap { $0 }
        return candidates.sorted { (order[$0.id] ?? 0) < (order[$1.id] ?? 0) }
    }

    private static func refresh(_ windows: [Window]) -> [Window] {
        // A minimized window need not have a drawable CG surface. Keep live AX objects even if CG no longer lists
        // the old ID, and match replacement objects by ID, then saved geometry/title.
        let inventory = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]]
        let alive = inventory.map { infos -> [pid_t: Set<CGWindowID>] in
            var ids: [pid_t: Set<CGWindowID>] = [:]
            for info in infos {
                if let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                   let id = info[kCGWindowNumber as String] as? CGWindowID { ids[pid, default: []].insert(id) }
            }
            return ids
        }
        let replacements = parallel(Array(Set(windows.filter { $0.element != nil }.map(\.pid)))) { pid -> (pid_t, [AXUIElement]?) in
            let app = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(app, 1)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
                  let elements = value as? [AXUIElement] else { return (pid, nil) }
            for element in elements {
                AXUIElementSetMessagingTimeout(element, 1)
            }
            return (pid, elements)
        }
        var byPID: [pid_t: [AXUIElement]] = [:]
        for (pid, elements) in replacements { if let elements { byPID[pid] = elements } }
        return windows.compactMap { saved in
            guard let old = saved.element else {
                return DispatchQueue.main.sync {
                    guard let local = saved.localWindow ?? NSApp.window(withWindowNumber: Int(saved.id)),
                          NSApp.windows.contains(local) else { return nil }
                    var updated = saved
                    updated.id = CGWindowID(exactly: local.windowNumber) ?? saved.id
                    return updated
                }
            }
            guard let elements = byPID[saved.pid] else { return saved }
            let exact = elements.first { CFEqual($0, old) || RemoteAX.windowID(of: $0) == saved.id }
            let geometry = elements.filter { element in
                guard let original = saved.frame, let current = frame(element) else { return false }
                return near(original, current)
            }
            let named = exact == nil ? elements.filter { element in
                guard let title = saved.title, !title.isEmpty else { return false }
                return string(element, kAXTitleAttribute) == title
            } : []
            let match = exact ?? geometry.first { saved.title != nil && string($0, kAXTitleAttribute) == saved.title }
                ?? (geometry.count == 1 ? geometry.first : nil)
                ?? (named.count == 1 ? named.first : nil)
            if let match {
                var updated = saved
                updated.element = match
                updated.id = RemoteAX.windowID(of: match) ?? saved.id
                updated.frame = frame(match) ?? saved.frame
                updated.title = string(match, kAXTitleAttribute) ?? saved.title
                return updated
            }
            if state(saved).value != nil || alive == nil || alive?[saved.pid]?.contains(saved.id) == true { return saved }
            return nil // No live AX object, matching replacement, or CG surface remains.
        }
    }

    private static func change(_ windows: [Window], minimized: Bool, on desktop: [Int]) -> [Bool] {
        // Keep apps visible while sending minimize requests. Some apps accept but ignore AXMinimized when hidden.
        // The transition cover, rather than application hiding, masks the Dock's animation queue.
        let attempted = parallel(windows) { window -> AXError? in
            guard SkyLight.visibleSpaces == desktop else { return nil }
            if let element = window.element {
                // Use the window picker's established restore sequence: some background apps accept the setter
                // without bringing their window back until it is focused and raised explicitly.
                if !minimized { SkyLight.focus(window: window.id, pid: window.pid) }
                let result = AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString,
                                                        minimized ? kCFBooleanTrue : kCFBooleanFalse)
                if !minimized { AXUIElementPerformAction(element, kAXRaiseAction as CFString) }
                return result
            }
            return DispatchQueue.main.sync {
                guard let local = window.localWindow ?? NSApp.window(withWindowNumber: Int(window.id)) else { return .invalidUIElement }
                if minimized { local.miniaturize(nil) } else { local.deminiaturize(nil) }
                return .success
            }
        }
        // AX setters acknowledge a request before the Dock finishes its animation. Keep covering the display until
        // the actual states agree; a closed window is complete, while a temporarily unresponsive app is retried.
        var pending = zip(windows, attempted).filter { $0.1 == .success || $0.1 == .cannotComplete }.map { $0.0 }
        let deadline = Date().addingTimeInterval(12)
        while !pending.isEmpty, SkyLight.visibleSpaces == desktop, Date() < deadline {
            let states = parallel(pending) { state($0).value }
            let needsRefresh = states.contains { $0 == nil }
            let visible = minimized ? nil : visibleWindows()
            pending = zip(pending, states).filter { $0.1 != minimized || (!minimized && !isVisible($0.0, in: visible ?? [])) }.map { $0.0 }
            if needsRefresh || !minimized { pending = refresh(pending) }
            if !pending.isEmpty { Thread.sleep(forTimeInterval: 0.01) }
        }
        // The observed state, not the setter's return code, decides whether restoration is complete. Unknown or
        // invalid objects stay in the restore list for another attempt instead of silently losing the window.
        let final = refresh(windows)
        let visible = minimized ? [] : visibleWindows()
        let states = parallel(final) { window -> Bool in
            guard state(window).value == minimized else { return false }
            if minimized { return true }
            return isVisible(window, in: visible)
        }
        let confirmed = Dictionary(zip(final.map(\.identity), states), uniquingKeysWith: { $0 || $1 })
        return windows.map { confirmed[$0.identity] ?? !minimized }
    }

    private static func visibleWindows() -> [[String: Any]] {
        CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    }

    private static func restoreLayout(_ saved: [Window], on desktop: [Int]) {
        guard SkyLight.visibleSpaces == desktop else { return }
        let visible = visibleWindows()
        let windows = saved.filter { isVisible($0, in: visible) }
        let levels = Dictionary(visible.compactMap { info -> (CGWindowID, Int)? in
            guard let id = info[kCGWindowNumber as String] as? CGWindowID,
                  let level = info[kCGWindowLayer as String] as? Int else { return nil }
            return (id, level)
        }, uniquingKeysWith: { first, _ in first })
        // Live AX geometry is for matching replacement objects; it must not replace the pre-minimize placement.
        _ = parallel(windows) { window -> Bool in
            guard SkyLight.visibleSpaces == desktop, let original = window.originalFrame else { return false }
            guard let element = window.element else {
                return DispatchQueue.main.sync {
                    guard let local = window.localWindow else { return false }
                    if local.frame != original { local.setFrame(original, display: true, animate: false) }
                    return true
                }
            }
            let current = frame(element)
            if current == original { return true }
            var size = original.size
            var origin = original.origin
            if current?.size != original.size, let value = AXValueCreate(.cgSize, &size) {
                _ = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
            }
            if let value = AXValueCreate(.cgPoint, &origin) {
                _ = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
            }
            return true
        }
        guard SkyLight.visibleSpaces == desktop else { return }
        // Ordinary activation can raise an app's other windows too. Activate without raising siblings and rebuild
        // the complete stack, including interleaved apps and non-minimizable windows, from back to front.
        // Only ordering is serialized, under the cover;
        // the actual minimize/restore requests remain concurrent.
        for window in windows.reversed() {
            guard SkyLight.visibleSpaces == desktop else { return }
            SkyLight.raisePreservingOthers(window: window.id, pid: window.pid)
            if let element = window.element {
                AXUIElementPerformAction(element, kAXRaiseAction as CFString)
            } else {
                DispatchQueue.main.sync { window.localWindow?.orderFrontRegardless() }
            }
            // AXRaise acknowledges before the app's drawing transaction is committed. A call to the next app
            // can otherwise overtake it, recreating the same random order despite serial AX calls.
            let peers = Set(windows.filter { levels[$0.id] == levels[window.id] }.map(\.id))
            let deadline = Date().addingTimeInterval(0.4)
            while SkyLight.visibleSpaces == desktop, Date() < deadline {
                let first = visibleWindows().compactMap { $0[kCGWindowNumber as String] as? CGWindowID }.first { peers.contains($0) }
                if first == window.id { break }
                Thread.sleep(forTimeInterval: 0.005)
            }
        }
    }

    private static func isVisible(_ window: Window, in infos: [[String: Any]]) -> Bool {
        infos.contains { info in
            guard info[kCGWindowOwnerPID as String] as? pid_t == window.pid else { return false }
            if info[kCGWindowNumber as String] as? CGWindowID == window.id { return true }
            guard let original = window.frame, let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let current = CGRect(dictionaryRepresentation: bounds) else { return false }
            return near(original, current)
        }
    }

    private static func string(_ element: AXUIElement, _ name: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func frame(_ element: AXUIElement) -> CGRect? {
        var position: CFTypeRef?, size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
              let position, let size, CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero, dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point), AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else { return nil }
        return CGRect(origin: point, size: dimensions)
    }

    private static func near(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 4 && abs(a.minY - b.minY) < 4 && abs(a.width - b.width) < 4 && abs(a.height - b.height) < 4
    }

    private static func hideApplications(_ pids: Set<pid_t>) -> [HiddenApplication] {
        let applications = parallel(Array(pids)) { pid -> HiddenApplication? in
            guard pid != ProcessInfo.processInfo.processIdentifier else { return nil }
            let app = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(app, 1)
            guard bool(app, kAXHiddenAttribute) == false else { return nil }
            _ = AXUIElementSetAttributeValue(app, kAXHiddenAttribute as CFString, kCFBooleanTrue)
            DispatchQueue.main.sync { _ = NSRunningApplication(processIdentifier: pid)?.hide() }
            return HiddenApplication(pid: pid, element: app)
        }.compactMap { $0 }
        let deadline = Date().addingTimeInterval(2)
        var pending = applications
        while !pending.isEmpty, Date() < deadline {
            pending = pending.filter { bool($0.element, kAXHiddenAttribute) != true }
            if !pending.isEmpty { Thread.sleep(forTimeInterval: 0.01) }
        }
        return applications // Retain the undo record even if the app's acknowledgement is late.
    }

    private static func orderLocalWindows(_ windows: [Window], visible: Bool) {
        DispatchQueue.main.sync {
            for window in windows where window.element == nil {
                guard let local = window.localWindow ?? NSApp.window(withWindowNumber: Int(window.id)) else { continue }
                if visible { local.orderFrontRegardless() } else { local.orderOut(nil) }
            }
        }
    }

    private static func unhideApplications(_ applications: [HiddenApplication]) {
        _ = parallel(applications) { app in
            _ = AXUIElementSetAttributeValue(app.element, kAXHiddenAttribute as CFString, kCFBooleanFalse)
            DispatchQueue.main.sync { _ = NSRunningApplication(processIdentifier: app.pid)?.unhide() }
        }
    }

    private static func state(_ window: Window) -> (value: Bool?, exists: Bool) {
        guard let element = window.element else {
            return DispatchQueue.main.sync {
                guard let local = window.localWindow ?? NSApp.window(withWindowNumber: Int(window.id)),
                      NSApp.windows.contains(local) else { return (nil, false) }
                return (local.isMiniaturized, true)
            }
        }
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &value)
        return (value as? Bool, error != .invalidUIElement && error != .attributeUnsupported && error != .noValue)
    }

    /// Submit the whole batch without waiting for any individual Accessibility call. In particular, different windows
    /// of the same app get independent requests. Only collecting the results waits, on the background coordinator.
    private static func parallel<Input, Output>(_ inputs: [Input], _ operation: @escaping (Input) -> Output) -> [Output] {
        let group = DispatchGroup()
        let lock = NSLock()
        var results: [Int: Output] = [:]
        for (index, input) in inputs.enumerated() {
            DispatchQueue.global(qos: .userInitiated).async(group: group) {
                let result = operation(input)
                lock.lock()
                results[index] = result
                lock.unlock()
            }
        }
        group.wait()
        return inputs.indices.map { results[$0]! }
    }

    private static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? Bool
    }
}
