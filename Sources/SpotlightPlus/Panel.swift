import AppKit
import SwiftUI
import Carbon.HIToolbox

let panelSize = NSSize(width: 720, height: 600)

/// Shared UI state for the pop-up.
final class PanelState: ObservableObject {
    static let shared = PanelState()
    @Published var query = "" {
        didSet {
            guard query != oldValue else { return }
            selection = 0
            SearchEngine.shared.search(query)
        }
    }
    @Published var selection = 0
    @Published var focusToken = 0          // bumped each time the panel opens, to refocus the field
    var draggingItem: URL?                  // pinned tile being reordered

    /// Back to the pinned apps.
    func goHome() { query = "" }

    func reset() {
        query = ""
        selection = 0
        draggingItem = nil
        focusToken += 1
    }
}

/// Invisible strips along the panel's edges and corners for resizing it with the mouse. A borderless window's own
/// resize area is a pixel or two wide, which is hard to hit; these are wider and show the resize cursors.
/// Clicks anywhere else pass straight through to the content.
final class ResizeHandlesView: NSView {
    private struct Edges: OptionSet {
        let rawValue: Int
        static let left = Edges(rawValue: 1), right = Edges(rawValue: 2), top = Edges(rawValue: 4), bottom = Edges(rawValue: 8)
    }

    private let thickness: CGFloat = 7
    private let corner: CGFloat = 16
    private var dragging: Edges = []
    private var startMouse = NSPoint.zero
    private var startFrame = NSRect.zero
    var onResizeEnd: (() -> Void)?

    override var mouseDownCanMoveWindow: Bool { false }       // the window must not move while resizing
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }   // the first click on an edge already resizes

    private func edges(at p: NSPoint) -> Edges {
        var e: Edges = []
        if p.x < thickness || (p.x < corner && (p.y < thickness || p.y > bounds.height - thickness)) { e.insert(.left) }
        if p.x > bounds.width - thickness || (p.x > bounds.width - corner && (p.y < thickness || p.y > bounds.height - thickness)) { e.insert(.right) }
        if p.y < thickness || (p.y < corner && (p.x < thickness || p.x > bounds.width - thickness)) { e.insert(.bottom) }
        if p.y > bounds.height - thickness || (p.y > bounds.height - corner && (p.x < thickness || p.x > bounds.width - thickness)) { e.insert(.top) }
        return e
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        edges(at: convert(point, from: superview)).isEmpty ? nil : self
    }

    override func resetCursorRects() {
        let t = thickness, c = corner, w = bounds.width, h = bounds.height
        let horizontal = NSCursor.resizeLeftRight, vertical = NSCursor.resizeUpDown
        addCursorRect(NSRect(x: 0, y: c, width: t, height: h - 2 * c), cursor: horizontal)
        addCursorRect(NSRect(x: w - t, y: c, width: t, height: h - 2 * c), cursor: horizontal)
        addCursorRect(NSRect(x: c, y: 0, width: w - 2 * c, height: t), cursor: vertical)
        addCursorRect(NSRect(x: c, y: h - t, width: w - 2 * c, height: t), cursor: vertical)
        let southwestNortheast = Self.diagonalCursor(.bottomLeft), southeastNorthwest = Self.diagonalCursor(.bottomRight)
        addCursorRect(NSRect(x: 0, y: 0, width: c, height: c), cursor: southwestNortheast)
        addCursorRect(NSRect(x: w - c, y: h - c, width: c, height: c), cursor: southwestNortheast)
        addCursorRect(NSRect(x: w - c, y: 0, width: c, height: c), cursor: southeastNorthwest)
        addCursorRect(NSRect(x: 0, y: h - c, width: c, height: c), cursor: southeastNorthwest)
    }

    private enum Diagonal { case bottomLeft, bottomRight }

    /// Diagonal resize arrows: a public cursor on macOS 15 and later, the closest ordinary one before that.
    private static func diagonalCursor(_ kind: Diagonal) -> NSCursor {
        if #available(macOS 15.0, *) {
            return NSCursor.frameResize(position: kind == .bottomLeft ? .bottomLeft : .bottomRight, directions: .all)
        }
        return NSCursor.crosshair
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        window?.invalidateCursorRects(for: self)
    }

    override func mouseDown(with event: NSEvent) {
        dragging = edges(at: convert(event.locationInWindow, from: nil))
        startMouse = NSEvent.mouseLocation
        startFrame = window?.frame ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, !dragging.isEmpty else { return }
        let dx = NSEvent.mouseLocation.x - startMouse.x, dy = NSEvent.mouseLocation.y - startMouse.y
        let minimum = window.minSize
        var frame = startFrame
        if dragging.contains(.right) { frame.size.width = max(minimum.width, startFrame.width + dx) }
        if dragging.contains(.left) {
            frame.size.width = max(minimum.width, startFrame.width - dx)
            frame.origin.x = startFrame.maxX - frame.size.width
        }
        if dragging.contains(.top) { frame.size.height = max(minimum.height, startFrame.height + dy) }
        if dragging.contains(.bottom) {
            frame.size.height = max(minimum.height, startFrame.height - dy)
            frame.origin.y = startFrame.maxY - frame.size.height
        }
        window.setFrame(frame, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        dragging = []
        onResizeEnd?()
    }
}

/// Borderless floating window with a translucent, rounded background.
final class SpotlightPanel: NSPanel {
    /// Called when a drag on the edge handles ends.
    var onResizeEnd: (() -> Void)? {
        didSet { handles?.onResizeEnd = onResizeEnd }
    }
    private var handles: ResizeHandlesView?

    init(content: NSView) {
        super.init(contentRect: NSRect(origin: .zero, size: panelSize),
                   styleMask: [.borderless, .resizable], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .modalPanel
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true     // drag it by any empty area
        minSize = NSSize(width: 520, height: 400)   // drag any edge to resize

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: panelSize))
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.maskImage = Self.roundedMask(radius: 18)
        content.frame = effect.bounds
        content.autoresizingMask = [.width, .height]
        effect.addSubview(content)
        let handles = ResizeHandlesView(frame: effect.bounds)
        handles.autoresizingMask = [.width, .height]
        effect.addSubview(handles)              // on top of the content, so it sees clicks at the edges first
        self.handles = handles
        contentView = effect
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

final class PanelController: NSObject, NSWindowDelegate {
    static let shared = PanelController()

    var suppressAutoHide = false
    /// True while the code itself moves or resizes the panel, so that isn't remembered as the user's choice.
    private var placing = false
    private let sizeKey = "panelSize", originKey = "panelOrigin"
    static let rememberSizeKey = "rememberWindowSize", rememberPositionKey = "rememberWindowPosition"
    private var panel: SpotlightPanel!
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?
    private var isHiding = false

    private override init() {
        super.init()
        panel = SpotlightPanel(content: NSHostingView(rootView: SpotlightPlusView()))
        panel.delegate = self
        panel.onResizeEnd = { [weak self] in self?.rememberFrame() }
        // Clicking outside every SpotlightPlus window hides the panel, whichever of our windows had focus.
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil,
                                               queue: .main) { [weak self] _ in
            guard let self, !self.suppressAutoHide else { return }
            self.hide(restoreFocus: false)
        }
    }

    var isVisible: Bool { panel.isVisible }
    var frame: NSRect { panel.frame }

    func toggle() { isVisible ? hide(restoreFocus: true) : show() }

    func show() {
        PanelState.shared.reset()
        RunningApps.shared.refresh()

        // Where you left it, if that's still on a screen; otherwise centred on the screen with the mouse pointer,
        // slightly above the middle (like Spotlight).
        placing = true
        let mouse = NSEvent.mouseLocation
        let size = rememberedSize ?? panelSize
        var frame = defaultFrame(on: NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main, size: size)
        if let origin = rememberedOrigin {
            let remembered = NSRect(origin: origin, size: size)
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(remembered) }) { frame = remembered }
        }
        panel.setFrame(frame, display: false)
        placing = false

        let front = NSWorkspace.shared.frontmostApplication
        previousApp = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : front
        activateSelf()   // lets us hand focus cleanly to whatever app gets launched
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    /// Runs a modal dialog while the panel stays on screen behind it (dropped below the dialog's level, and kept
    /// from auto-hiding when it loses focus). Afterwards the panel takes focus again.
    @discardableResult
    func keepVisible<T>(during body: () -> T) -> T {
        let wasVisible = panel.isVisible
        let level = panel.level
        suppressAutoHide = true
        if wasVisible { panel.level = .floating }
        WindowPreviewController.shared.hideNow()
        let result = body()
        suppressAutoHide = false
        panel.level = level
        if wasVisible { settleAfterPopup() }
        return result
    }

    /// A popup window has closed. If you had already clicked away from SpotlightPlus while it was open (closing a
    /// window's X doesn't bring the app back), the panel goes too; otherwise it takes focus again.
    private func settleAfterPopup() {
        guard panel.isVisible else { return }
        if NSApp.isActive { panel.makeKeyAndOrderFront(nil) } else { hide(restoreFocus: false) }
    }

    /// Keeps the panel from hiding when it loses focus (a picker window is open next to it).
    func holdOpen(_ hold: Bool) {
        suppressAutoHide = hold
        if !hold { settleAfterPopup() }
    }

    /// restoreFocus: give focus back to the app you were in (Esc / hotkey), vs. not (an app was launched).
    func hide(restoreFocus: Bool) {
        guard panel.isVisible, !isHiding else { return }
        isHiding = true                      // orderOut fires windowDidResignKey; don't re-enter
        let previous = previousApp
        previousApp = nil
        removeKeyMonitor()
        WindowPreviewController.shared.hideNow()
        panel.orderOut(nil)
        isHiding = false
        if restoreFocus { previous?.activate(options: []) }
    }

    // MARK: Size and position

    private func defaultFrame(on screen: NSScreen?, size: NSSize) -> NSRect {
        guard let f = screen?.visibleFrame else { return NSRect(origin: panel.frame.origin, size: size) }
        return NSRect(x: f.midX - size.width / 2, y: f.midY - size.height / 2 + f.height * 0.04,
                      width: size.width, height: size.height)
    }

    /// The size from the last time you resized the panel, when "Remember window size" is on (it is by default).
    private var rememberedSize: NSSize? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Self.rememberSizeKey) as? Bool ?? true,
              let text = defaults.string(forKey: sizeKey) else { return nil }
        let size = NSSizeFromString(text)
        guard size.width >= panel.minSize.width, size.height >= panel.minSize.height else { return nil }
        return size
    }

    /// The position from the last time you moved the panel, when "Remember window position" is on (off by default).
    private var rememberedOrigin: NSPoint? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Self.rememberPositionKey) as? Bool ?? false,
              let text = defaults.string(forKey: originKey) else { return nil }
        return NSPointFromString(text)
    }

    /// Both are always written down; the two settings only decide whether they're used at the next opening.
    fileprivate func rememberFrame() {
        guard !placing, panel.isVisible else { return }
        UserDefaults.standard.set(NSStringFromSize(panel.frame.size), forKey: sizeKey)
        UserDefaults.standard.set(NSStringFromPoint(panel.frame.origin), forKey: originKey)
    }

    func windowDidMove(_ notification: Notification) { rememberFrame() }
    func windowDidEndLiveResize(_ notification: Notification) { rememberFrame() }

    /// Back to the standard size, centred, and forget the remembered size and position.
    func resetFrame() {
        UserDefaults.standard.removeObject(forKey: sizeKey)
        UserDefaults.standard.removeObject(forKey: originKey)
        placing = true
        panel.setFrame(defaultFrame(on: panel.screen ?? NSScreen.main, size: panelSize), display: true)
        placing = false
    }

    func windowDidResignKey(_ notification: Notification) {
        if !suppressAutoHide { hide(restoreFocus: false) }   // clicked somewhere else
    }

    // MARK: Keyboard: ↑ ↓ to move, ↩ to open, ⌘↩ to show in Finder, Esc to clear / close

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            let state = PanelState.shared
            let results = SearchEngine.shared.results
            switch Int(event.keyCode) {
            case kVK_Escape:
                if state.query.isEmpty { self.hide(restoreFocus: true) } else { state.query = "" }
                return nil
            case kVK_DownArrow where !results.isEmpty:
                state.selection = min(state.selection + 1, results.count - 1)
                return nil
            case kVK_UpArrow where !results.isEmpty:
                state.selection = max(state.selection - 1, 0)
                return nil
            case kVK_Return, kVK_ANSI_KeypadEnter:
                guard results.indices.contains(state.selection) else { return event }
                if let answer = results[state.selection].copyText {
                    Launcher.copy(answer)
                    self.hide(restoreFocus: true)
                    return nil
                }
                let url = results[state.selection].url
                if event.modifierFlags.contains(.command) && url.isFileURL {
                    Launcher.reveal(url)
                } else {
                    Launcher.open(url)
                }
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
        keyMonitor = nil
    }
}
