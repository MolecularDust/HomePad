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

    func reset() {
        query = ""
        selection = 0
        draggingItem = nil
        focusToken += 1
    }
}

/// Borderless floating window with a translucent, rounded background.
final class SpotlightPanel: NSPanel {
    init(content: NSView) {
        super.init(contentRect: NSRect(origin: .zero, size: panelSize),
                   styleMask: [.borderless], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .modalPanel
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true     // drag it by any empty area

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: panelSize))
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.maskImage = Self.roundedMask(radius: 18)
        content.frame = effect.bounds
        content.autoresizingMask = [.width, .height]
        effect.addSubview(content)
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
    private var panel: SpotlightPanel!
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?
    private var isHiding = false

    private override init() {
        super.init()
        panel = SpotlightPanel(content: NSHostingView(rootView: SpotlightPlusView()))
        panel.delegate = self
    }

    var isVisible: Bool { panel.isVisible }
    var frame: NSRect { panel.frame }

    func toggle() { isVisible ? hide(restoreFocus: true) : show() }

    func show() {
        PanelState.shared.reset()
        RunningApps.shared.refresh()

        // Center on the screen that has the mouse pointer, slightly above the middle (like Spotlight).
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let f = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: f.midX - panelSize.width / 2,
                                         y: f.midY - panelSize.height / 2 + f.height * 0.04))
        }

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
        if wasVisible { panel.makeKeyAndOrderFront(nil) }
        return result
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
