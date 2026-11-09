import AppKit
import SwiftUI

/// Taskbar mode (HomePadMode): a Windows 11–style taskbar along the bottom of the main screen, with HomePad's Start
/// button and the running apps centred together.
///
/// It's a borderless panel just above the Dock's window level, on every Space but not over full-screen apps, and it never
/// takes the keyboard focus (a click on it leaves the app you're in active, as the Dock does). macOS lets only the Dock
/// keep windows off part of the screen, so the Dock stays at the bottom, as tall as the taskbar, under it
/// (DockControl.reserveForTaskbar); the taskbar takes the height the Dock keeps, so maximized windows end at its top.
/// It's opaque, or the Dock would show through.
final class Taskbar {
    static let shared = Taskbar()
    static let height: CGFloat = 48

    private var panel: TaskbarPanel?
    private var observers: [NSObjectProtocol] = []

    /// Where the taskbar is on screen, while it's shown.
    var frame: NSRect? { panel?.isVisible == true ? panel?.frame : nil }

    func show() {
        if panel == nil { build() }
        place()
        panel?.orderFrontRegardless()
        if observers.isEmpty {
            // The Dock's space changes after it restarts; screens come and go.
            for name in [NSApplication.didChangeScreenParametersNotification, DockControl.changed] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    self?.place()
                })
            }
        }
    }

    func hide() {
        panel?.orderOut(nil)
        WindowPreviewController.shared.hideNow()
    }

    /// Full width along the bottom of the screen with the menu bar, as tall as the space the Dock keeps there (until
    /// the Dock has its place, the standard height).
    private func place() {
        guard let screen = NSScreen.screens.first, let panel else { return }
        let reserved = DockControl.reservedHeight
        let height = (30...90).contains(reserved) ? reserved : Self.height
        panel.setFrame(NSRect(x: screen.frame.minX, y: screen.frame.minY, width: screen.frame.width, height: height),
                       display: true)
    }

    private func build() {
        let panel = TaskbarPanel(contentRect: NSRect(x: 0, y: 0, width: 800, height: Self.height),
                                 styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)     // over the Dock
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isOpaque = true
        panel.backgroundColor = .windowBackgroundColor      // follows light and dark
        panel.hasShadow = false
        panel.isMovable = false
        panel.contentView = FirstClickHostingView(rootView: TaskbarView().localized())
        self.panel = panel
    }

    /// An icon's frame on screen, from its frame in the taskbar's content (top-left origin).
    func screenRect(_ rect: CGRect) -> NSRect? {
        guard let window = panel?.frame else { return nil }
        return NSRect(x: window.minX + rect.minX, y: window.maxY - rect.maxY, width: rect.width, height: rect.height)
    }
}

private final class TaskbarPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Takes the first click even though HomePad isn't the active app (the taskbar never makes it active).
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// The app in front, for the taskbar's "active" mark.
final class FrontmostApp: ObservableObject {
    static let shared = FrontmostApp()
    @Published private(set) var pid: pid_t? = NSWorkspace.shared.frontmostApplication?.processIdentifier

    private init() {
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                          object: nil, queue: .main) { [weak self] note in
            self?.pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
        }
    }
}

struct TaskbarView: View {
    @ObservedObject private var running = RunningApps.shared
    @ObservedObject private var order = RunningOrder.shared

    var body: some View {
        HStack(spacing: 2) {
            StartButton()
            ForEach(order.shown(running.apps), id: \.self) { url in
                TaskbarIcon(url: url)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) { Rectangle().fill(Color.primary.opacity(0.12)).frame(height: 0.5) }
    }
}

/// HomePad's own icon at the start of the taskbar: opens and closes the panel, like the Windows Start button.
private struct StartButton: View {
    @State private var hovering = false

    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .frame(width: 30, height: 30)
            .frame(width: 44, height: 40)
            .background(RoundedRectangle(cornerRadius: 6).fill(hovering ? Color.primary.opacity(0.10) : .clear))
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .onTapGesture { PanelController.shared.toggle() }
            .help(L("Start"))
    }
}

/// A running app: a click brings it forward, or hides it when it's already in front (as Windows minimizes it); the
/// mark under it is wide for the app in front. Pointing at it shows its windows; right-click gives the tile's menu.
private struct TaskbarIcon: View {
    let url: URL
    @ObservedObject private var front = FrontmostApp.shared
    @State private var hovering = false
    @State private var frame = CGRect.zero

    var body: some View {
        let app = RunningApps.shared.app(for: url)
        let active = app.map { $0.processIdentifier == front.pid } ?? false
        VStack(spacing: 3) {
            Image(nsImage: IconCache.icon(for: url))
                .resizable()
                .interpolation(.high)
                .frame(width: 30, height: 30)
            Capsule()
                .fill(active ? Color.accentColor : Color.secondary.opacity(0.7))
                .frame(width: active ? 16 : 6, height: 3)
                .animation(.easeOut(duration: 0.15), value: active)
        }
        .frame(width: 44, height: 44)
        .background(RoundedRectangle(cornerRadius: 6).fill(hovering || active ? Color.primary.opacity(active ? 0.08 : 0.10) : .clear))
        .background(GeometryReader { geo in
            Color.clear.onAppear { frame = geo.frame(in: .global) }.onChange(of: geo.frame(in: .global)) { frame = $0 }
        })
        .contentShape(Rectangle())
        .onHover { inside in
            hovering = inside
            if inside, let app {                 // so its menu is current by the time it's right-clicked
                ClosableWindows.shared.refresh()
                AppMenus.shared.refresh(app)
            }
            WindowPreviewController.shared.hover(app: app, over: inside, tile: .zero,
                                                 screenTile: Taskbar.shared.screenRect(frame))
        }
        .onTapGesture {
            WindowPreviewController.shared.hideNow()
            guard let app else { return }
            if app.isActive {
                Launcher.hide(url)
            } else {
                activateSelf()          // the taskbar never makes HomePad active, and macOS lets only the active app hand over
                Launcher.open(url)
            }
        }
        .help(IconCache.name(for: url))
        .contextMenu { AppTileMenu(url: url, isRunning: true) }
    }
}
