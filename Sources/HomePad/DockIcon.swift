import AppKit
import ApplicationServices

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

    static var problem: Problem? {
        if !AXIsProcessTrusted() { return .noAccessibility }
        if DockControl.isHidden { return .dockHidden }
        if !isKeptInDock { return .notInDock }
        return nil
    }

    /// The icon's frame in screen coordinates (origin bottom left, like NSWindow), if it's there to be found.
    static func frame() -> NSRect? {
        guard problem == nil,
              let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier
        else { return nil }
        let me = Bundle.main.bundleURL.standardizedFileURL.path
        let dock = AXUIElementCreateApplication(pid)
        for list in children(of: dock) {
            for item in children(of: list) {
                guard let url = attribute(item, "AXURL") as? URL, url.standardizedFileURL.path == me,
                      let position = point(item, kAXPositionAttribute), let size = size(item) else { continue }
                // Accessibility counts from the top left of the main display; AppKit from the bottom left.
                let top = NSScreen.screens.first?.frame.height ?? 0
                return NSRect(x: position.x, y: top - position.y - size.height, width: size.width, height: size.height)
            }
        }
        return nil
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
