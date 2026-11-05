import AppKit
import ApplicationServices
import os

/// HomePad's own icon in the macOS Dock, for "Open above the HomePad icon in the Dock" (Settings → Dock): the panel
/// then opens right by that icon, like the Windows Start menu by its button.
///
/// The Dock's icons are Accessibility elements of the Dock process, each with its position, size and URL, so this needs
/// the Accessibility permission (HomePad has it for the double-tap key). The Dock's side of the screen comes from its
/// own preferences.
enum DockIcon {
    static let settingKey = "panelAboveDockIcon"
    static var isOn: Bool { UserDefaults.standard.bool(forKey: settingKey) }

    enum Side { case bottom, left, right }

    /// Why the panel can't go by the icon right now (nil: it can).
    enum Problem { case notInDock, dockHidden, noAccessibility }

    /// Where the Dock sits on the screen.
    static var side: Side {
        let domain = "com.apple.dock" as CFString
        CFPreferencesAppSynchronize(domain)
        switch CFPreferencesCopyAppValue("orientation" as CFString, domain) as? String {
        case "left": return .left
        case "right": return .right
        default: return .bottom
        }
    }

    /// True if HomePad is one of the apps kept in the Dock (what you drag there and "Options → Keep in Dock" does).
    static var isKeptInDock: Bool {
        let domain = "com.apple.dock" as CFString
        CFPreferencesAppSynchronize(domain)
        guard let items = CFPreferencesCopyAppValue("persistent-apps" as CFString, domain) as? [[String: Any]] else { return false }
        let me = Bundle.main.bundleURL.standardizedFileURL.path
        return items.contains { item in
            guard let url = ((item["tile-data"] as? [String: Any])?["file-data"] as? [String: Any])?["_CFURLString"] as? String,
                  let path = URL(string: url)?.standardizedFileURL.path else { return false }
            return path.hasSuffix("/") ? String(path.dropLast()) == me : path == me
        }
    }

    /// What stops the panel from going by the icon (for Settings' note). The icon itself is what counts: the Dock's saved
    /// list is only read when the icon can't be found, to tell "not in the Dock" from "not there at this moment".
    static var problem: Problem? {
        if !AXIsProcessTrusted() { return .noAccessibility }
        if DockControl.isHidden { return .dockHidden }
        if findIcon() == nil && !isKeptInDock { return .notInDock }
        return nil
    }

    private static let log = Logger(subsystem: "local.mike.HomePad", category: "dock-icon")

    /// The icon's frame in screen coordinates (origin bottom left, like NSWindow), if it's there to be found. Right
    /// after the icon was dragged to a new place the Dock is still rebuilding its icons, so a miss is tried again a
    /// few times over about half a second before giving up (the panel then opens in the middle).
    static func frame() -> NSRect? {
        guard AXIsProcessTrusted(), !DockControl.isHidden else { return nil }
        for attempt in 0..<6 {
            if let icon = findIcon() {
                if attempt > 0 { log.notice("icon found on attempt \(attempt + 1)") }
                return icon
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        log.error("icon not found: \(describeDock(), privacy: .public)")
        return nil
    }

    /// One look through the Dock's icons for HomePad's own.
    private static func findIcon() -> NSRect? {
        guard let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier
        else { return nil }
        let me = Bundle.main.bundleURL.standardizedFileURL.path
        let name = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ?? "HomePad"
        let dock = AXUIElementCreateApplication(pid)
        for list in children(of: dock) {
            for item in children(of: list) {
                // By the app's location; an icon that doesn't give its URL (as it can while the Dock is busy) by its name.
                let url = (attribute(item, "AXURL") as? URL)?.standardizedFileURL.path
                let title = attribute(item, kAXTitleAttribute) as? String
                guard url == me || (url == nil && title == name),
                      let position = point(item, kAXPositionAttribute), let size = size(item), size.width > 0 else { continue }
                // Accessibility counts from the top left of the main display; AppKit from the bottom left.
                let top = NSScreen.screens.first?.frame.height ?? 0
                return NSRect(x: position.x, y: top - position.y - size.height, width: size.width, height: size.height)
            }
        }
        return nil
    }

    /// What the Dock shows, for the log when the icon isn't found: how many icons, and what HomePad's looks like.
    private static func describeDock() -> String {
        guard let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier
        else { return "no Dock process" }
        let dock = AXUIElementCreateApplication(pid)
        var items = 0, mine = ""
        for list in children(of: dock) {
            for item in children(of: list) {
                items += 1
                let title = attribute(item, kAXTitleAttribute) as? String ?? "-"
                if title.contains("HomePad") {
                    mine += " [title \(title), url \((attribute(item, "AXURL") as? URL)?.path ?? "none"), position \(point(item, kAXPositionAttribute).map { "\($0)" } ?? "none"), size \(size(item).map { "\($0)" } ?? "none")]"
                }
            }
        }
        return "\(items) Dock items, kept in Dock: \(isKeptInDock), HomePad items:\(mine.isEmpty ? " none" : mine), running from \(Bundle.main.bundleURL.path)"
    }

    /// The panel's frame by the icon: above it for a Dock at the bottom, beside it for one at the side, kept on screen.
    static func panelFrame(size: NSSize, near icon: NSRect) -> NSRect {
        let gap: CGFloat = 8
        let screen = NSScreen.screens.first { $0.frame.intersects(icon) } ?? NSScreen.main
        let area = screen?.visibleFrame ?? icon.insetBy(dx: -400, dy: -400)
        var origin: NSPoint
        switch side {
        case .bottom: origin = NSPoint(x: icon.midX - size.width / 2, y: icon.maxY + gap)
        case .left: origin = NSPoint(x: icon.maxX + gap, y: icon.midY - size.height / 2)
        case .right: origin = NSPoint(x: icon.minX - size.width - gap, y: icon.midY - size.height / 2)
        }
        origin.x = min(max(origin.x, area.minX + gap), area.maxX - size.width - gap)
        origin.y = min(max(origin.y, area.minY + gap), area.maxY - size.height - gap)
        return NSRect(origin: origin, size: size)
    }

    // MARK: Accessibility helpers

    private static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        (attribute(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
    }

    private static func point(_ element: AXUIElement, _ name: String) -> CGPoint? {
        guard let value = attribute(element, name), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value as! AXValue, .cgPoint, &point) ? point : nil
    }

    private static func size(_ element: AXUIElement) -> CGSize? {
        guard let value = attribute(element, kAXSizeAttribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value as! AXValue, .cgSize, &size) ? size : nil
    }
}
