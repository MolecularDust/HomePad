import AppKit
import SwiftUI

/// Full Disk Access has no prompt and no way for an app to add itself to the list: you drag the app in or press +.
/// This small window sits next to System Settings with HomePad's icon to drag into the list. It goes away once the
/// permission is on, or with its close button.
enum DragInHelper {
    private static var panel: NSPanel?

    static func show() {
        close()
        let host = NSHostingView(rootView: DragInView(close: close))
        host.frame.size = host.fittingSize
        let p = NSPanel(contentRect: host.frame, styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
                        backing: .buffered, defer: false)
        p.contentView = host
        p.isFloatingPanel = true
        p.level = .floating
        p.hidesOnDeactivate = false
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isMovableByWindowBackground = true
        panel = p
        place(attempt: 0)
    }

    static func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    /// Next to System Settings' window once it's on screen (it can take a moment to open), at its left edge near
    /// the bottom, where the list and its + button are.
    private static func place(attempt: Int) {
        guard let panel else { return }
        if let settings = settingsWindowFrame() {
            let size = panel.frame.size
            let screen = NSScreen.screens.first { $0.frame.intersects(settings) } ?? NSScreen.main
            let visible = screen?.visibleFrame ?? settings
            var origin = NSPoint(x: settings.minX - size.width - 12, y: settings.minY + 40)
            if origin.x < visible.minX { origin.x = settings.minX + 20 }    // no room on the left: over its corner
            origin.y = max(visible.minY, min(origin.y, visible.maxY - size.height))
            panel.setFrameOrigin(origin)
            panel.orderFrontRegardless()
        } else if attempt < 40 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { place(attempt: attempt + 1) }
        } else {
            panel.center()
            panel.orderFrontRegardless()
        }
    }

    /// System Settings' main window, in screen coordinates (window bounds can be read without Screen Recording).
    private static func settingsWindowFrame() -> NSRect? {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        guard let info = windows.first(where: {
                  $0[kCGWindowOwnerName as String] as? String == "System Settings" && $0[kCGWindowLayer as String] as? Int == 0
              }),
              let dict = info[kCGWindowBounds as String] as? NSDictionary,
              let cg = CGRect(dictionaryRepresentation: dict), cg.width > 200 else { return nil }
        // Window bounds count from the top of the main screen; AppKit counts from its bottom.
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        return NSRect(x: cg.minX, y: top - cg.maxY, width: cg.width, height: cg.height)
    }
}

private struct DragInView: View {
    let close: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                Button(action: close) { Image(systemName: "xmark").font(.system(size: 10, weight: .bold)) }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("Close")
            }
            AppIconDragSource().frame(width: 72, height: 72).help("Drag into the Full Disk Access list")
            Text("Drag HomePad into the list")
                .font(.system(size: 13, weight: .semibold))
            Text("then turn its switch on.\nOr press + under the list and choose HomePad.")
                .font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(EdgeInsets(top: 10, leading: 16, bottom: 16, trailing: 12))
        .frame(width: 220)
        .background(VisualEffect().clipShape(RoundedRectangle(cornerRadius: 14)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.1)))
    }
}

private struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .popover
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// HomePad's icon; dragging it drags the app itself (its file URL), which is what System Settings' list accepts.
private struct AppIconDragSource: NSViewRepresentable {
    func makeNSView(context: Context) -> DragSourceView { DragSourceView() }
    func updateNSView(_ nsView: DragSourceView, context: Context) {}

    final class DragSourceView: NSView, NSDraggingSource {
        private let icon = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)

        override func draw(_ dirtyRect: NSRect) { icon.draw(in: bounds) }
        override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
        override var mouseDownCanMoveWindow: Bool { false }

        override func mouseDragged(with event: NSEvent) {
            let item = NSDraggingItem(pasteboardWriter: Bundle.main.bundleURL as NSURL)
            item.setDraggingFrame(bounds, contents: icon)
            beginDraggingSession(with: [item], event: event, source: self)
        }

        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            .copy
        }
    }
}
