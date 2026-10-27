import AppKit

/// A corner of the screen. HomePad watches the ones you pick (Settings → Shortcut → Hot corners) and opens the panel
/// in that corner when the pointer rests there, like macOS's own hot corners (which can't open an app).
enum HotCorner: String, CaseIterable, Identifiable {
    case topLeft, topRight, bottomLeft, bottomRight
    var id: String { rawValue }

    var title: String {
        switch self {
        case .topLeft: return "Top left"
        case .topRight: return "Top right"
        case .bottomLeft: return "Bottom left"
        case .bottomRight: return "Bottom right"
        }
    }

    var isLeft: Bool { self == .topLeft || self == .bottomLeft }
    var isTop: Bool { self == .topLeft || self == .topRight }

    /// The point of this corner on a screen (AppKit coordinates: y grows upwards).
    func point(of frame: NSRect) -> NSPoint {
        NSPoint(x: isLeft ? frame.minX : frame.maxX, y: isTop ? frame.maxY : frame.minY)
    }

    /// The panel's frame in this corner of the screen's usable area (below the menu bar, beside the Dock).
    func frame(for size: NSSize, on screen: NSScreen) -> NSRect {
        let area = screen.visibleFrame.insetBy(dx: 8, dy: 8)
        let width = min(size.width, area.width), height = min(size.height, area.height)
        return NSRect(x: isLeft ? area.minX : area.maxX - width, y: isTop ? area.maxY - height : area.minY,
                      width: width, height: height)
    }

    /// What macOS itself does in this corner (System Settings → Desktop & Dock → Hot Corners), if anything.
    /// Only actions that need no modifier key count: one with a key held clashes with nothing.
    var systemAction: String? {
        let key: String
        switch self {
        case .topLeft: key = "tl"
        case .topRight: key = "tr"
        case .bottomLeft: key = "bl"
        case .bottomRight: key = "br"
        }
        let dock = "com.apple.dock" as CFString
        guard let action = CFPreferencesCopyAppValue("wvous-\(key)-corner" as CFString, dock) as? Int, action > 1 else { return nil }
        if let modifier = CFPreferencesCopyAppValue("wvous-\(key)-modifier" as CFString, dock) as? Int, modifier != 0 { return nil }
        switch action {
        case 2: return "Mission Control"
        case 3: return "Application Windows"
        case 4: return "Desktop"
        case 5: return "Start Screen Saver"
        case 6: return "Disable Screen Saver"
        case 10: return "Put Display to Sleep"
        case 11: return "Launchpad"
        case 12: return "Notification Centre"
        case 13: return "Lock Screen"
        case 14: return "Quick Note"
        default: return "another action"
        }
    }
}

/// Watches the pointer and opens the panel when it rests in a chosen corner.
/// The pointer's position can be read without any permission, and checking it 20 times a second costs next to nothing;
/// nothing runs at all while no corner is chosen.
final class HotCornerMonitor {
    static let shared = HotCornerMonitor()
    static let defaultsKey = "hotCorners"

    /// How close to the corner the pointer must be, and how long it must stay there (so flinging the pointer at a
    /// menu doesn't open the panel).
    private let reach: CGFloat = 3
    private let dwell: TimeInterval = 0.2
    /// After firing, the pointer must leave the corner by this much before that corner fires again.
    private let rearm: CGFloat = 40

    private var timer: Timer?
    private var arrivedAt: Date?
    private var fired = false

    /// Stored as one text value ("topLeft,bottomRight"), so Settings can watch it with @AppStorage.
    static func decode(_ text: String) -> Set<HotCorner> {
        Set(text.split(separator: ",").compactMap { HotCorner(rawValue: String($0)) })
    }

    static func encode(_ corners: Set<HotCorner>) -> String {
        HotCorner.allCases.filter(corners.contains).map(\.rawValue).joined(separator: ",")
    }

    static var chosen: Set<HotCorner> { decode(UserDefaults.standard.string(forKey: defaultsKey) ?? "") }

    /// Call at launch and whenever the setting changes.
    func apply() {
        timer?.invalidate()
        timer = nil
        arrivedAt = nil
        fired = false
        guard !Self.chosen.isEmpty else { return }
        let t = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in self?.check() }
        t.tolerance = 0.02
        RunLoop.main.add(t, forMode: .common)      // also while a menu is open or a window is being dragged
        timer = t
    }

    private func check() {
        let mouse = NSEvent.mouseLocation
        // Holding a button is a drag or a selection, not a trip to the corner.
        guard NSEvent.pressedMouseButtons == 0 else { arrivedAt = nil; return }
        let chosen = Self.chosen
        var hit: (HotCorner, NSScreen)?
        var distance = CGFloat.greatestFiniteMagnitude
        for screen in NSScreen.screens {
            for corner in chosen {
                let p = corner.point(of: screen.frame)
                let d = max(abs(mouse.x - p.x), abs(mouse.y - p.y))
                distance = min(distance, d)
                if d <= reach { hit = (corner, screen) }
            }
        }
        if fired {
            if distance > rearm { fired = false }
            return
        }
        guard let (corner, screen) = hit else { arrivedAt = nil; return }
        let now = Date()
        guard let arrived = arrivedAt else { arrivedAt = now; return }
        guard now.timeIntervalSince(arrived) >= dwell else { return }
        fired = true
        arrivedAt = nil
        // Like macOS's corners, the same corner closes it again.
        let panel = PanelController.shared
        if panel.isVisible { panel.hide(restoreFocus: true) } else { panel.show(in: corner, of: screen) }
    }
}
