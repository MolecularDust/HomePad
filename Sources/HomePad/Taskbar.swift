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

/// The app in front, for the taskbar's "active" mark: by its location, since an app can run as several processes and
/// the one in front needn't be the one its icon goes by.
final class FrontmostApp: ObservableObject {
    static let shared = FrontmostApp()
    @Published private(set) var path: String? = NSWorkspace.shared.frontmostApplication?.bundleURL.map { normalized($0).path }

    private init() {
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                          object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.path = app?.bundleURL.map { normalized($0).path }
        }
    }
}

struct TaskbarView: View {
    @ObservedObject private var running = RunningApps.shared
    @ObservedObject private var pins = TaskbarPins.shared
    @ObservedObject private var order = RunningOrder.taskbar
    @ObservedObject private var shown = TaskbarShown.shared

    var body: some View {
        HStack(spacing: 2) {
            StartButton()
            ForEach(Taskbar.items(), id: \.self) { url in
                TaskbarIcon(url: url)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .contextMenu { TaskbarMenu() }      // the blank space; an icon has its own menu
        .overlay(alignment: .top) { Rectangle().fill(Color.primary.opacity(0.12)).frame(height: 0.5) }
    }
}

extension Taskbar {
    /// What the taskbar shows after the Start button: what's pinned to it and every running app, once each, in the
    /// taskbar's own order (`RunningOrder.taskbar`; an app that isn't placed yet goes last, alphabetically).
    static func items() -> [URL] {
        var seen = Set<URL>()
        let running = RunningApps.shared.apps.compactMap { $0.bundleURL.map(normalized) }.filter(TaskbarShown.shared.shows)
        let all = TaskbarPins.shared.urls + running
        return RunningOrder.taskbar.sorted(all.filter { seen.insert($0).inserted })
    }
}

extension RunningOrder {
    /// The taskbar's order: pinned items and running apps together, apart from the Running section's.
    static let taskbar = RunningOrder(key: "taskbarOrder")
}

/// Apps, files and folders pinned to the taskbar (stored as paths under `taskbarPins`): a list of its own, apart from
/// HomePad's categories. A pinned app stays on the taskbar when it isn't running.
final class TaskbarPins: ObservableObject {
    static let shared = TaskbarPins()
    static let key = "taskbarPins"
    @Published private(set) var paths: [String] = UserDefaults.standard.stringArray(forKey: TaskbarPins.key) ?? []

    var urls: [URL] { paths.map { URL(fileURLWithPath: $0) } }

    func contains(_ url: URL) -> Bool { paths.contains(normalized(url).path) }

    /// Pinned at the end of the taskbar (an app already there as a running app stays where it is).
    func pin(_ url: URL) {
        guard !contains(url) else { return }
        RunningOrder.taskbar.fix(Taskbar.items() + [normalized(url)])
        paths.append(normalized(url).path)
        UserDefaults.standard.set(paths, forKey: Self.key)
    }

    func unpin(_ url: URL) {
        paths.removeAll { $0 == normalized(url).path }
        UserDefaults.standard.set(paths, forKey: Self.key)
    }
}

/// Running apps switched off in Settings → Running apps → Show in taskbar (stored as paths under `taskbarExcluded`):
/// they stay off the taskbar while they run. A pinned item is always shown.
final class TaskbarShown: ObservableObject {
    static let shared = TaskbarShown()
    static let key = "taskbarExcluded"
    @Published private(set) var excluded: Set<String> = Set(UserDefaults.standard.stringArray(forKey: TaskbarShown.key) ?? [])

    func shows(_ url: URL) -> Bool { !excluded.contains(normalized(url).path) }

    func set(_ url: URL, shown: Bool) {
        let path = normalized(url).path
        if shown { excluded.remove(path) } else { excluded.insert(path) }
        UserDefaults.standard.set(excluded.sorted(), forKey: Self.key)
    }
}

/// Where Add App… and Add File or Folder… put what you choose: a HomePad category or the taskbar.
enum PinTarget {
    case category(UUID)
    case taskbar

    func contains(_ url: URL) -> Bool {
        switch self {
        case .category: return CategoryStore.shared.contains(url)
        case .taskbar: return TaskbarPins.shared.contains(url)
        }
    }

    func add(_ url: URL) {
        switch self {
        case .category(let id): CategoryStore.shared.add(url, to: id)
        case .taskbar: TaskbarPins.shared.pin(url)
        }
    }
}

/// Right-click on the taskbar's blank space.
private struct TaskbarMenu: View {
    var body: some View {
        Button("Add App…") { DispatchQueue.main.async { AppPicker.show(to: .taskbar) } }
        Button("Add File or Folder…") { DispatchQueue.main.async { FilePicker.show(to: .taskbar) } }
        Divider()
        Button("Settings…") { (NSApp.delegate as? AppDelegate)?.openSettings() }
    }
}

/// A taskbar icon being dragged. The others make room as it passes over them, as on Windows; it can't be dropped
/// anywhere else (the type is HomePad's own, see RunningDrag), and letting go elsewhere leaves it where it got to.
final class TaskbarDrag: ObservableObject {
    static let shared = TaskbarDrag()
    @Published private(set) var item: URL?
    private var timer: Timer?

    func begin(_ url: URL) {
        RunningOrder.taskbar.fix(Taskbar.items())
        WindowPreviewController.shared.hideNow()
        item = url
        // SwiftUI doesn't say when a drag that wasn't dropped on an icon ends: the mouse button tells.
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            if NSEvent.pressedMouseButtons & 1 == 0 { self?.end() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func end() {
        timer?.invalidate()
        timer = nil
        item = nil
    }
}

private struct TaskbarDropDelegate: DropDelegate {
    let target: URL

    func validateDrop(info: DropInfo) -> Bool { TaskbarDrag.shared.item != nil }

    func dropEntered(info: DropInfo) {
        guard let dragging = TaskbarDrag.shared.item, dragging != target else { return }
        withAnimation(.easeInOut(duration: 0.15)) { RunningOrder.taskbar.move(dragging, onto: target) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        TaskbarDrag.shared.end()
        return true
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

/// A pinned item or a running app. A click opens it, brings it forward, or hides it when it's already in front (as
/// Windows minimizes it); the mark under a running app is wide for the one in front. Pointing at a running app shows
/// its windows; right-click gives the tile's menu; drag it along the taskbar to move it.
private struct TaskbarIcon: View {
    let url: URL
    @ObservedObject private var front = FrontmostApp.shared
    @ObservedObject private var drag = TaskbarDrag.shared
    @ObservedObject private var running = RunningApps.shared
    @State private var hovering = false
    @State private var frame = CGRect.zero

    var body: some View {
        let app = running.app(for: url)
        let active = app != nil && front.path == normalized(url).path
        VStack(spacing: 3) {
            Image(nsImage: IconCache.icon(for: url))
                .resizable()
                .interpolation(.high)
                .frame(width: 30, height: 30)
            Capsule()
                .fill(app == nil ? Color.clear : active ? Color.accentColor : Color.secondary.opacity(0.7))
                .frame(width: active ? 16 : 6, height: 3)
                .animation(.easeOut(duration: 0.15), value: active)
        }
        .frame(width: 44, height: 44)
        .background(RoundedRectangle(cornerRadius: 6).fill(hovering || active ? Color.primary.opacity(active ? 0.08 : 0.10) : .clear))
        .opacity(drag.item == url ? 0.4 : 1)
        .background(GeometryReader { geo in
            Color.clear.onAppear { frame = geo.frame(in: .global) }.onChange(of: geo.frame(in: .global)) { frame = $0 }
        })
        .contentShape(Rectangle())
        .onHover { inside in
            hovering = inside
            guard drag.item == nil else { return }
            if inside, let app {                 // so its menu is current by the time it's right-clicked
                ClosableWindows.shared.refresh()
                AppMenus.shared.refresh(app)
            }
            WindowPreviewController.shared.hover(app: app, over: inside && app != nil, tile: .zero,
                                                 screenTile: Taskbar.shared.screenRect(frame))
        }
        .onTapGesture {
            WindowPreviewController.shared.hideNow()
            if let app, app.isActive {
                Launcher.hide(url)
            } else {
                activateSelf()          // the taskbar never makes HomePad active, and macOS lets only the active app hand over
                Launcher.open(url)
            }
        }
        .onDrag {
            TaskbarDrag.shared.begin(url)
            return RunningDrag.provider(for: url)
        }
        .onDrop(of: [RunningDrag.type], delegate: TaskbarDropDelegate(target: url))
        .help(IconCache.name(for: url))
        .contextMenu { AppTileMenu(url: url, isRunning: app != nil, onTaskbar: true) }
    }
}
