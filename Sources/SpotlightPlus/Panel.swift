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
    @Published var pressedCategory: UUID?   // category row selected by pressing its title
    @Published var draggingCategory: UUID?  // category row being carried to a new place in the order
    @Published var isDragging = false       // a tile or a category title is in the air
    private var dragWatcher: Timer?
    private var lastDragActivity = Date()

    /// Called by drop targets whenever a drag moves over them, so a drag that is still moving is never taken for dead.
    func noteDragActivity() { lastDragActivity = Date() }

    /// A tile or category title was picked up. While dragging, passing over other things must not trigger them
    /// (hover colours, window previews).
    func beginDrag() {
        isDragging = true
        lastDragActivity = Date()
        WindowPreviewController.shared.hideNow()
        dragWatcher?.invalidate()
        let started = Date()
        // SwiftUI has no callback for a drag that ends without a drop. It counts as over when the mouse button is up
        // and no drop target has seen the pointer for a second. (Added for all run-loop modes: a drag runs the loop
        // in tracking mode.)
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self, Date().timeIntervalSince(started) > 0.4, NSEvent.pressedMouseButtons == 0,
                  Date().timeIntervalSince(self.lastDragActivity) > 1.0 else { return }
            self.endDrag()
        }
        RunLoop.main.add(timer, forMode: .common)
        dragWatcher = timer
    }

    func endDrag() {
        dragWatcher?.invalidate()
        dragWatcher = nil
        isDragging = false
        draggingItem = nil
        draggingCategory = nil
        pressedCategory = nil
        RowDrag.shared.reset()
    }

    /// The carried row is let go: it takes the place it has reached, at once (it is already drawn there).
    func dropCarriedRow() {
        let landing = RowDrag.shared.landing
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            if let (id, index) = landing { CategoryStore.shared.moveCategory(id, toIndex: index) }
            endDrag()
        }
    }

    /// Back to the pinned apps.
    func goHome() { query = "" }

    func reset() {
        query = ""
        selection = 0
        endDrag()
        focusToken += 1
    }
}

/// One invisible strip along an edge or in a corner of the panel, for resizing it with the mouse. A borderless
/// window's own resize area is a pixel or two wide, which is hard to hit; these are wider and show the resize
/// cursors. They exist only at the edges: a view laid over the whole window, even one that ignores clicks in the
/// middle, stops the window from being dragged by its background.
final class ResizeZoneView: NSView {
    struct Edges: OptionSet {
        let rawValue: Int
        static let left = Edges(rawValue: 1), right = Edges(rawValue: 2), top = Edges(rawValue: 4), bottom = Edges(rawValue: 8)
    }

    static let thickness: CGFloat = 7
    static let corner: CGFloat = 16

    private let edges: Edges
    private var startMouse = NSPoint.zero
    private var startFrame = NSRect.zero
    var onResizeEnd: (() -> Void)?

    init(edges: Edges, frame: NSRect, autoresizing: NSView.AutoresizingMask) {
        self.edges = edges
        super.init(frame: frame)
        autoresizingMask = autoresizing
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var mouseDownCanMoveWindow: Bool { false }       // the window must not move while resizing
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }   // the first click on an edge already resizes

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: cursor)
    }

    private var cursor: NSCursor {
        let horizontal = edges.contains(.left) || edges.contains(.right)
        let vertical = edges.contains(.top) || edges.contains(.bottom)
        if horizontal && vertical {
            // The corner running from bottom-left to top-right, or from bottom-right to top-left.
            let southwestNortheast = (edges.contains(.left) && edges.contains(.bottom)) || (edges.contains(.right) && edges.contains(.top))
            if #available(macOS 15.0, *) {
                return NSCursor.frameResize(position: southwestNortheast ? .bottomLeft : .bottomRight, directions: .all)
            }
            return NSCursor.crosshair
        }
        return horizontal ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        window?.invalidateCursorRects(for: self)
    }

    override func mouseDown(with event: NSEvent) {
        startMouse = NSEvent.mouseLocation
        startFrame = window?.frame ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let dx = NSEvent.mouseLocation.x - startMouse.x, dy = NSEvent.mouseLocation.y - startMouse.y
        let minimum = window.minSize
        var frame = startFrame
        if edges.contains(.right) { frame.size.width = max(minimum.width, startFrame.width + dx) }
        if edges.contains(.left) {
            frame.size.width = max(minimum.width, startFrame.width - dx)
            frame.origin.x = startFrame.maxX - frame.size.width
        }
        if edges.contains(.top) { frame.size.height = max(minimum.height, startFrame.height + dy) }
        if edges.contains(.bottom) {
            frame.size.height = max(minimum.height, startFrame.height - dy)
            frame.origin.y = startFrame.maxY - frame.size.height
        }
        window.setFrame(frame, display: true)
    }

    override func mouseUp(with event: NSEvent) { onResizeEnd?() }

    /// The eight zones for a view of the given size: four edges (between the corners) and four corners.
    static func zones(in size: NSSize) -> [ResizeZoneView] {
        let t = thickness, c = corner, w = size.width, h = size.height
        func zone(_ edges: Edges, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ mask: NSView.AutoresizingMask) -> ResizeZoneView {
            ResizeZoneView(edges: edges, frame: NSRect(x: x, y: y, width: width, height: height), autoresizing: mask)
        }
        return [
            zone(.left, 0, c, t, h - 2 * c, [.height, .maxXMargin]),
            zone(.right, w - t, c, t, h - 2 * c, [.height, .minXMargin]),
            zone(.bottom, c, 0, w - 2 * c, t, [.width, .maxYMargin]),
            zone(.top, c, h - t, w - 2 * c, t, [.width, .minYMargin]),
            zone([.left, .bottom], 0, 0, c, c, [.maxXMargin, .maxYMargin]),
            zone([.right, .bottom], w - c, 0, c, c, [.minXMargin, .maxYMargin]),
            zone([.left, .top], 0, h - c, c, c, [.maxXMargin, .minYMargin]),
            zone([.right, .top], w - c, h - c, c, c, [.minXMargin, .minYMargin]),
        ]
    }
}

/// Borderless floating window with a translucent, rounded background.
final class SpotlightPanel: NSPanel {
    /// Called when a drag on the edge handles ends.
    var onResizeEnd: (() -> Void)? {
        didSet { zones.forEach { $0.onResizeEnd = onResizeEnd } }
    }
    private var zones: [ResizeZoneView] = []

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
        effect.material = .windowBackground      // solid: nothing behind the panel shows through
        effect.blendingMode = .withinWindow
        effect.state = .active
        effect.maskImage = Self.roundedMask(radius: 18)
        content.frame = effect.bounds
        content.autoresizingMask = [.width, .height]
        effect.addSubview(content)
        zones = ResizeZoneView.zones(in: effect.bounds.size)
        zones.forEach { effect.addSubview($0) }     // on top of the content, so they see clicks at the edges first
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
        activateSelf()   // the app must be active for typing to reach the search field
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

    func move(to origin: NSPoint) { panel.setFrameOrigin(origin) }

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
                // Typing while the search field isn't focused (after a click on empty space): the text goes to the field.
                // Once that has started, every key joins the queue until it is flushed, so the order is kept.
                let blocked: NSEvent.ModifierFlags = [.command, .control]
                if event.modifierFlags.intersection(blocked).isEmpty, (self.flushScheduled || !(self.panel.firstResponder is NSText)),
                   let text = event.characters, let scalar = text.unicodeScalars.first {
                    if Int(event.keyCode) == kVK_Delete {
                        self.queueTyping(nil)
                    } else if scalar.value >= 32 && scalar.value != 127 && scalar.value < 0xF700 {
                        self.queueTyping(text)         // 0xF700 and up are the arrow and function keys
                    } else {
                        return event
                    }
                    return nil
                }
                return event
            }
        }
    }

    private var queuedKeys: [String?] = []       // nil stands for Delete
    private var flushScheduled = false

    /// Typing while the search field isn't focused: focus it, then put the typed characters in once it is.
    /// (Focusing selects its text, so each character is inserted at the end rather than typed over the selection.)
    private func queueTyping(_ key: String?) {
        queuedKeys.append(key)
        guard !flushScheduled else { return }
        flushScheduled = true
        PanelState.shared.focusToken += 1
        flushTyping(attempt: 1)
    }

    private func flushTyping(attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self else { return }
            guard let editor = self.panel.firstResponder as? NSTextView else {
                if attempt < 5 { self.flushTyping(attempt: attempt + 1) } else { self.queuedKeys = []; self.flushScheduled = false }
                return
            }
            editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
            for key in self.queuedKeys {
                if let key { editor.insertText(key, replacementRange: editor.selectedRange()) } else { editor.deleteBackward(nil) }
            }
            self.queuedKeys = []
            self.flushScheduled = false
        }
    }

    private func removeKeyMonitor() {
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
        keyMonitor = nil
    }
}

/// The category row being carried. Kept apart from PanelState on purpose: the offset changes with every mouse move,
/// and only the rows' positions should be redrawn for that, not the whole panel (every tile, the running apps...).
final class RowDrag: ObservableObject {
    static let shared = RowDrag()
    @Published private(set) var offset: CGFloat = 0     // how far the carried row is from where it rests (down is positive)
    @Published private(set) var target: Int?            // the place in the order it would land in
    private(set) var carried: UUID?
    var frames: [UUID: CGRect] = [:]                    // where the rows rest, measured when nothing is carried
    private var order: [UUID] = []
    private var from = 0

    func begin(_ id: UUID) {
        order = CategoryStore.shared.categories.map(\.id)
        guard let index = order.firstIndex(of: id) else { return }
        from = index
        carried = id
        offset = 0
        target = index
    }

    func move(to offset: CGFloat) {
        guard let carried, let frame = frames[carried] else { return }
        self.offset = offset
        // Past every row whose middle the carried row's middle has crossed.
        let middle = frame.midY + offset
        var to = from
        for (index, other) in order.enumerated() where index != from {
            guard let rest = frames[other] else { continue }
            if index > from, middle > rest.midY { to = max(to, index) }
            if index < from, middle < rest.midY { to = min(to, index) }
        }
        if to != target { target = to }
    }

    /// How far a row is drawn from its resting place: the carried one follows the pointer, the ones it has passed
    /// slide one row (its height plus the gap) out of the way.
    func shift(for id: UUID) -> CGFloat {
        guard let carried, let target else { return 0 }
        if id == carried { return offset }
        guard let index = order.firstIndex(of: id), let frame = frames[carried] else { return 0 }
        let gap = order.count > 1 ? (frames[order[1]]?.minY ?? 0) - (frames[order[0]]?.maxY ?? 0) : 0
        if target > from, index > from, index <= target { return -(frame.height + gap) }
        if target < from, index >= target, index < from { return frame.height + gap }
        return 0
    }

    var landing: (UUID, Int)? { carried.flatMap { id in target.map { (id, $0) } } }

    func reset() {
        guard carried != nil || offset != 0 else { return }
        carried = nil
        target = nil
        offset = 0
    }
}
