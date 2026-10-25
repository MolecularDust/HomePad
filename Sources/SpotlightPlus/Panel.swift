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
    var draggingItem: URL? {               // pinned tile being reordered
        didSet {
            guard let item = draggingItem, oldValue != item else { return }
            dragOrigin = CategoryStore.shared.location(of: item)
            // Shown a moment later, so the picture the system takes of the tile for the pointer is still the icon.
            DispatchQueue.main.async { if PanelState.shared.draggingItem == item { TileDrag.shared.show(item) } }
        }
    }
    /// Where the dragged tile was picked up. The other tiles make room for it as it passes over them, so this is where
    /// it goes back to if the drag doesn't end in a drop (Esc, or let go elsewhere).
    private var dragOrigin: (category: UUID, index: Int)?
    private var leaveWork: DispatchWorkItem?
    // Not published: views that need these read them when they run, so starting or ending a drag doesn't redraw
    // the whole panel. What a drag shows on screen comes from RowDrag.
    var draggingCategory: UUID?             // category row being carried to a new place in the order
    var isDragging = false                  // a tile or a category title is in the air
    private var dragWatcher: Timer?
    private var lastDragActivity = Date()

    /// Called by drop targets whenever a drag moves over them, so a drag that is still moving is never taken for dead.
    /// Over a tile or a category again after leaving them: the empty slot shows again where the tile is.
    func noteDragActivity() {
        lastDragActivity = Date()
        leaveWork?.cancel()
        if let item = draggingItem { TileDrag.shared.show(item) }
    }

    /// The drag left a drop target. If no other one takes it at once, it is over none of them: it was cancelled with
    /// Esc, or is outside the tiles. Then everything looks as before the drag, the tile back in its place, until it
    /// comes back over the tiles. (Moving from one tile to the next reports leaving one and entering the other, and
    /// crossing the gap between categories takes a moment, hence the short wait.)
    func noteDragLeft() {
        guard draggingItem != nil else { return }
        leaveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.draggingItem != nil, Date().timeIntervalSince(self.lastDragActivity) > 0.12 else { return }
            self.returnDraggedTile(animated: true)
            TileDrag.shared.show(nil)
        }
        leaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    /// The tile was dropped on a tile or a category: its new place stands.
    func finishTileDrop() {
        dragOrigin = nil
        endDrag()
    }

    private func returnDraggedTile(animated: Bool) {
        guard let item = draggingItem, let origin = dragOrigin,
              let now = CategoryStore.shared.location(of: item), now.category != origin.category || now.index != origin.index else { return }
        let move = { CategoryStore.shared.move(item, toCategory: origin.category, at: origin.index) }
        if animated { withAnimation(.easeInOut(duration: 0.15), move) } else { move() }
    }

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
        // A drop on a tile or category ends the drag at once; this only catches drops elsewhere, and quickly, since the
        // dragged tile's place shows a placeholder until the drag is over.
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, Date().timeIntervalSince(started) > 0.4 else { return }
            let quiet = Date().timeIntervalSince(self.lastDragActivity)
            // While a dragged tile is over the tiles, they hear from it about 25 times a second, even when the pointer
            // is still. Silence means it was cancelled (Esc) or is elsewhere: everything goes back as it was at once,
            // the button may still be held. If it comes back over the tiles, the slot and the live order return.
            if quiet > 0.2, self.draggingItem != nil, TileDrag.shared.item != nil {
                self.returnDraggedTile(animated: true)
                TileDrag.shared.show(nil)
            }
            guard NSEvent.pressedMouseButtons == 0, quiet > 0.3 else { return }
            self.endDrag()
        }
        RunLoop.main.add(timer, forMode: .common)
        dragWatcher = timer
    }

    /// Without a drop (Esc, or let go outside the tiles), the dragged tile goes back where it was.
    func endDrag() {
        dragWatcher?.invalidate()
        dragWatcher = nil
        leaveWork?.cancel()
        returnDraggedTile(animated: false)
        dragOrigin = nil
        isDragging = false
        draggingItem = nil
        TileDrag.shared.show(nil)
        draggingCategory = nil
        RowDrag.shared.reset()
    }

    /// The carried row is let go: it takes the place it has reached, at once (it is already drawn there).
    func dropCarriedRow() {
        let landing = RowDrag.shared.landing
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            if let (id, index) = landing { CategoryStore.shared.moveRow(id, toIndex: index) }
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

    /// A stretchable rounded rectangle for NSVisualEffectView.maskImage. (Rounding the view's layer instead leaves
    /// the blurred background, and the shadow made from it, square at the corners.)
    static func roundedMask(radius: CGFloat) -> NSImage {
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
        // Lay the panel out once now, while nothing is waiting for it. (The first opening is still slower than the
        // rest, about 160 ms against 26: that is the app becoming active and text input starting up the first time.)
        panel.contentView?.layoutSubtreeIfNeeded()
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
        ClosableWindows.shared.refresh()

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

    func performDrag(with event: NSEvent) { panel.performDrag(with: event) }

    /// An ordinary window (Settings) opened from the panel: the panel stays on screen behind it as an ordinary
    /// window too, so other apps (System Settings, to allow a permission) can come in front of both. When that window
    /// closes, the panel floats on top again and takes focus.
    func stayBehind(_ behind: Bool) {
        if behind {
            suppressAutoHide = true
            WindowPreviewController.shared.hideNow()
            panel.level = .normal
            panel.orderFrontRegardless()   // at the front of the ordinary windows, just under the one being opened
        } else {
            suppressAutoHide = false
            panel.level = .modalPanel
            guard panel.isVisible else { return }
            activateSelf()
            panel.makeKeyAndOrderFront(nil)
            PanelState.shared.focusToken += 1        // the cursor back in the search field
        }
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

    private var saveWork: DispatchWorkItem?

    /// Moving or resizing reports every step; the frame is written down once, when the steps stop.
    private func rememberFrameSoon() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.rememberFrame() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func windowDidMove(_ notification: Notification) { if !placing { rememberFrameSoon() } }
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

    /// Puts the queued keys in as soon as the field has focus: SwiftUI gives it focus on its next update, usually
    /// within a frame, so this looks every few milliseconds rather than waiting a fixed time.
    private func flushTyping(attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + (attempt == 1 ? 0 : 0.008)) { [weak self] in
            guard let self else { return }
            guard let editor = self.panel.firstResponder as? NSTextView else {
                if attempt < 60 { self.flushTyping(attempt: attempt + 1) } else { self.queuedKeys = []; self.flushScheduled = false }
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

/// The pinned tile being dragged, for drawing its place as an empty slot. Apart from PanelState so that starting and
/// ending a drag redraws the tiles only.
final class TileDrag: ObservableObject {
    static let shared = TileDrag()
    @Published private(set) var item: URL?

    func show(_ new: URL?) { if item != new { item = new } }
}

/// The category row being carried. Kept apart from PanelState on purpose: the offset changes with every mouse move,
/// and only the rows' positions should be redrawn for that, not the whole panel (every tile, the running apps...).
final class RowDrag: ObservableObject {
    static let shared = RowDrag()
    @Published private(set) var offset: CGFloat = 0     // how far the carried row is from where it rests (down is positive)
    @Published private(set) var target: Int?            // the place in the order it would land in
    @Published private(set) var pressed: UUID?          // the row selected by pressing its title (and then carried)
    private(set) var carried: UUID?
    var frames: [UUID: CGRect] = [:]                    // where the rows rest, measured when nothing is carried
    private var order: [UUID] = []
    private var from = 0

    func press(_ id: UUID?) { if pressed != id { pressed = id } }

    func begin(_ id: UUID) {
        order = CategoryStore.shared.visibleRows
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
        if pressed != nil { pressed = nil }
        guard carried != nil || offset != 0 else { return }
        carried = nil
        target = nil
        offset = 0
    }
}
