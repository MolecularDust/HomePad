import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Taskbar mode (HomePadMode): a Windows 11–style taskbar along the bottom of the main screen, with HomePad's Start
/// button and the running apps centred together.
///
/// It's a borderless panel just above ordinary windows (other apps' floating windows come over it), on every Space but not over full-screen apps, and it never
/// takes the keyboard focus (a click on it leaves the app you're in active, as the Dock does). The Dock is hidden
/// meanwhile. macOS lets only the Dock keep windows off part of the screen, so WindowFitter makes windows that reach
/// under the taskbar shorter.
///
/// Settings → Taskbar → "Automatically hide the taskbar": the taskbar slides off the bottom of the screen, comes back when
/// the pointer rests on the bottom edge, and goes again when the pointer leaves it. It stays up while anything of its own
/// is open: HomePad's panel, a pop-up (volume, calendar), a window preview, a menu or a drag. Windows then use the whole
/// screen (WindowFitter stands down).
final class Taskbar {
    static let shared = Taskbar()
    static let height: CGFloat = 48
    static let autoHideKey = "taskbarAutoHide"
    /// How long the pointer must rest on the bottom edge before the taskbar comes back (a pass along it doesn't count).
    private static let revealDelay: TimeInterval = 0.3

    private var panel: TaskbarPanel?
    private var observers: [NSObjectProtocol] = []

    /// The taskbar's window (the tray's pop-ups tell its clicks from clicks elsewhere).
    var window: NSWindow? { panel }

    static var autoHides: Bool { UserDefaults.standard.bool(forKey: autoHideKey) }

    /// Where the taskbar is on screen when it's up, while the mode is on (also when it has slid away: this is where it
    /// comes back to, and where HomePad's panel and the pop-ups go).
    var frame: NSRect? { panel?.isVisible == true ? upFrame : nil }

    /// Full width along the bottom of the main screen.
    private var upFrame: NSRect? {
        NSScreen.screens.first.map { NSRect(x: $0.frame.minX, y: $0.frame.minY, width: $0.frame.width, height: Self.height) }
    }

    /// Where it is while slid away: just below the screen.
    private var awayFrame: NSRect? { upFrame.map { $0.offsetBy(dx: 0, dy: -$0.height) } }

    private var isAway = false
    private var timer: Timer?
    private var settingTimer: Timer?
    private var edgeSince: Date?
    private var leftSince: Date?
    private var lastAutoHide = false

    func show() {
        if panel == nil { build() }
        isAway = false
        place()
        panel?.orderFrontRegardless()
        lastAutoHide = Self.autoHides
        WindowFitter.shared.start()
        if observers.isEmpty {
            // The Dock's space changes after it restarts; screens come and go.
            observers.append(NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                self?.place()
            })
            // The Settings switch (UserDefaults tells of every change; only this one matters).
            observers.append(NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.autoHideMayHaveChanged()
            })
        }
        startWatching()
        // The switch is also looked at twice a second: a change made outside the app (defaults write, a synced
        // preference) sends no notification.
        if settingTimer == nil {
            let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.autoHideMayHaveChanged() }
            RunLoop.main.add(t, forMode: .common)
            settingTimer = t
        }
    }

    func hide() {
        timer?.invalidate()
        timer = nil
        settingTimer?.invalidate()
        settingTimer = nil
        panel?.orderOut(nil)
        WindowFitter.shared.stop()
        TaskbarLabel.shared.hover(nil, over: nil)
        TaskbarFlyout.shared.close()
        WindowPreviewController.shared.hideNow()
    }

    /// Full width along the bottom of the screen with the menu bar (below it, while slid away).
    private func place() {
        guard let panel, let up = upFrame else { return }
        panel.setFrame(isAway ? up.offsetBy(dx: 0, dy: -up.height) : up, display: true)
    }

    private func autoHideMayHaveChanged() {
        let now = Self.autoHides
        guard now != lastAutoHide, panel?.isVisible == true else { return }
        lastAutoHide = now
        if now { startWatching() } else { reveal(animated: true) }
        // Windows that were kept above the taskbar are fitted again, or may now use the whole screen.
        WindowFitter.shared.refit()
    }

    // MARK: Sliding away and back

    /// Looks at the pointer 20 times a second while the taskbar is on and may slide away (no permission needed).
    private func startWatching() {
        timer?.invalidate()
        timer = nil
        guard Self.autoHides else { return }
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Anything of the taskbar's own that is open keeps it up, as the Start menu does on Windows.
    private var keepsUp: Bool {
        PanelController.shared.isVisible || TaskbarFlyout.shared.isOpen || WindowPreviewController.shared.isShowing
            || TaskbarDrag.shared.item != nil
            // A menu or a drag runs the loop in this mode.
            || RunLoop.main.currentMode == .eventTracking
    }

    private func tick() {
        guard Self.autoHides, let up = frame else { return }
        let pointer = NSEvent.mouseLocation
        let now = Date()
        if isAway {
            // The bottom edge, away from a bottom hot corner (which opens HomePad itself).
            var edge = pointer.y <= up.minY + 1 && pointer.x >= up.minX && pointer.x <= up.maxX
            let corners = HotCornerMonitor.chosen
            if edge, corners.contains(.bottomLeft), pointer.x < up.minX + 12 { edge = false }
            if edge, corners.contains(.bottomRight), pointer.x > up.maxX - 12 { edge = false }
            if edge || keepsUp {
                edgeSince = edgeSince ?? now
                if keepsUp || now.timeIntervalSince(edgeSince!) >= Self.revealDelay { reveal(animated: true) }
            } else {
                edgeSince = nil
            }
        } else {
            let over = up.insetBy(dx: 0, dy: -2).contains(pointer)
            if over || keepsUp {
                leftSince = nil
            } else {
                leftSince = leftSince ?? now
                if now.timeIntervalSince(leftSince!) >= 0.4 { conceal(animated: true) }
            }
        }
    }

    private func reveal(animated: Bool) {
        edgeSince = nil
        leftSince = nil
        guard isAway, let panel, let up = frame else { isAway = false; return }
        isAway = false
        move(panel, to: up, animated: animated)
    }

    private func conceal(animated: Bool) {
        guard !isAway, let panel, let away = awayFrame else { return }
        isAway = true
        leftSince = nil
        TaskbarLabel.shared.hover(nil, over: nil)
        move(panel, to: away, animated: animated)
    }

    private func move(_ panel: NSPanel, to frame: NSRect, animated: Bool) {
        guard animated else { panel.setFrame(frame, display: true); return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(frame, display: true)
        }
    }

    private func build() {
        let panel = TaskbarPanel(contentRect: NSRect(x: 0, y: 0, width: 800, height: Self.height),
                                 styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        // Just above ordinary windows, as on Windows: other apps' floating windows (a dictation bar, a picture-in-picture
        // video, an always-on-top tool) come over the taskbar instead of under it.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue + 1)
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
        guard let window = frame else { return nil }
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
    @AppStorage(Taskbar.iconsAlignmentKey) private var iconsAlignment = Taskbar.Alignment.center
    @AppStorage(Taskbar.startAlignmentKey) private var startAlignment = Taskbar.Alignment.center

    private var icons: some View {
        ForEach(Taskbar.items(), id: \.self) { url in TaskbarIcon(url: url) }
    }

    var body: some View {
        // "Left" is the leading side: the right in Arabic and Persian, as Windows mirrors it.
        Group {
            if iconsAlignment == .left {
                HStack(spacing: 2) { StartButton(); icons }
                    .padding(.leading, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if startAlignment == .left {
                ZStack {
                    StartButton()
                        .padding(.leading, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 2) { icons }
                }
            } else {
                HStack(spacing: 2) { StartButton(); icons }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .trailing) { TaskbarTrayView() }
        .contentShape(Rectangle())
        .contextMenu { TaskbarMenu() }      // the blank space; an icon has its own menu
        // Dropped on the blank space: pinned at the end.
        .onDrop(of: TaskbarFileDrop.types, delegate: TaskbarFileDropDelegate(target: .end))
        .overlay(alignment: .top) { Rectangle().fill(Color.primary.opacity(0.12)).frame(height: 0.5) }
    }
}

extension Taskbar {
    /// Settings → Mode → Taskbar: where the app icons go, and where HomePad's icon goes while they're centred (with
    /// the app icons on the left, it's always on the left, before them).
    enum Alignment: String { case center, left }
    static let iconsAlignmentKey = "taskbarIconsAlignment"
    static let startAlignmentKey = "taskbarStartAlignment"

    /// HomePad's icon is on the left: chosen so, or the app icons are on the left.
    static var startIsLeft: Bool {
        let d = UserDefaults.standard
        return d.string(forKey: iconsAlignmentKey) == Alignment.left.rawValue
            || d.string(forKey: startAlignmentKey) == Alignment.left.rawValue
    }

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
    /// Pinned at the end of the taskbar (an app already there as a running app stays where it is), or, dropped on the
    /// taskbar, just before the icon it was let go on (an item already pinned moves there).
    func pin(_ url: URL, before target: URL? = nil) {
        let url = normalized(url)
        guard !contains(url) || target != nil else { return }
        var shown = Taskbar.items()
        if !shown.contains(url) { shown.append(url) }
        RunningOrder.taskbar.fix(shown)
        if !contains(url) {
            paths.append(url.path)
            UserDefaults.standard.set(paths, forKey: Self.key)
        }
        if let target, normalized(target) != url {
            var order = RunningOrder.taskbar.order
            order.removeAll { $0 == url.path }
            let index = order.firstIndex(of: normalized(target).path) ?? order.count
            order.insert(url.path, at: index)
            RunningOrder.taskbar.set(order)
        }
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

/// Over a taskbar icon: a taskbar icon being moved along it, or something dragged in from outside (pinned before
/// this icon).
private struct TaskbarDropDelegate: DropDelegate {
    let target: URL
    private var outside: TaskbarFileDropDelegate { TaskbarFileDropDelegate(target: .before(target)) }

    func validateDrop(info: DropInfo) -> Bool { TaskbarDrag.shared.item != nil || outside.validateDrop(info: info) }

    func dropEntered(info: DropInfo) {
        guard let dragging = TaskbarDrag.shared.item else { outside.dropEntered(info: info); return }
        guard dragging != target else { return }
        withAnimation(.easeInOut(duration: 0.15)) { RunningOrder.taskbar.move(dragging, onto: target) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        TaskbarDrag.shared.item != nil ? DropProposal(operation: .move) : outside.dropUpdated(info: info)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard TaskbarDrag.shared.item != nil else { return outside.performDrop(info: info) }
        TaskbarDrag.shared.end()
        return true
    }
}

/// Apps, files and folders dragged onto the taskbar, from Finder or from HomePad's panel, are pinned where they're let
/// go, as on Windows (no slot opens up meanwhile, as neither Windows nor the Dock show one).
enum TaskbarFileDrop {
    /// Finder gives file URLs; HomePad's own tiles give their path as text (and PanelState says which tile it is).
    static let types: [UTType] = [.fileURL, .utf8PlainText]
}

/// Where a drop from outside lands.
enum TaskbarDropTarget {
    case before(URL)
    case end
}

struct TaskbarFileDropDelegate: DropDelegate {
    let target: TaskbarDropTarget

    /// A tile from HomePad's panel that is a real app, file or folder (not one of HomePad's own folders).
    private var panelItem: URL? {
        guard let url = PanelState.shared.draggingItem, url.isFileURL,
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    func validateDrop(info: DropInfo) -> Bool {
        TaskbarDrag.shared.item == nil && (panelItem != nil || info.hasItemsConforming(to: [.fileURL]))
    }

    func dropEntered(info: DropInfo) {
        if validateDrop(info: info) { PanelState.shared.noteDragActivity() }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard validateDrop(info: info) else { return nil }
        PanelState.shared.noteDragActivity()
        return DropProposal(operation: .copy)
    }

    func performDrop(info: DropInfo) -> Bool {
        let before: URL?
        switch target {
        case .before(let url): before = url
        case .end: before = nil
        }
        if let item = panelItem {
            TaskbarPins.shared.pin(item, before: before)
            PanelState.shared.endDrag()             // the tile stays where it was in HomePad
            return true
        }
        let providers = info.itemProviders(for: [.fileURL])
        guard !providers.isEmpty else { return false }
        // Several items keep their order, each landing before the same icon.
        var urls = [URL?](repeating: nil, count: providers.count)
        let group = DispatchGroup()
        for (i, provider) in providers.enumerated() {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                DispatchQueue.main.async {          // handed over on a background queue
                    urls[i] = url
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) {
            for url in urls.compactMap({ $0 }) where url.isFileURL && FileManager.default.fileExists(atPath: url.path) {
                TaskbarPins.shared.pin(url, before: before)
            }
        }
        return true
    }
}

/// HomePad's own icon at the start of the taskbar: opens and closes the panel, like the Windows Start button (its label
/// says HomePad).
private struct StartButton: View {
    @ObservedObject private var drag = TaskbarDrag.shared
    @State private var hovering = false
    @State private var frame = CGRect.zero

    var body: some View {
        // Laid out like the app icons (an icon over the room for their running mark), so it sits at their height.
        VStack(spacing: 3) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 30, height: 30)
            Color.clear.frame(width: 6, height: 3)
        }
            .frame(width: 44, height: 44)
            .background(TaskbarHighlight(on: hovering && drag.item == nil, strong: false))
            .background(FrameReader(frame: $frame))
            .contentShape(Rectangle())
            .onHover { inside in
                hovering = inside
                TaskbarLabel.shared.hover(inside ? "HomePad" : nil, over: Taskbar.shared.screenRect(frame))
            }
            .onTapGesture {
                TaskbarLabel.shared.hover(nil, over: nil)
                PanelController.shared.toggle()
            }
    }
}

/// The pale rounded square behind an icon that is pointed at or in front, as on Windows 11.
struct TaskbarHighlight: View {
    let on: Bool
    /// The app in front: a little brighter than pointing.
    let strong: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = scheme == .dark
        RoundedRectangle(cornerRadius: 6)
            // A faint grey on the light taskbar (white disappeared into it), a faint light tint on the dark one.
            .fill((dark ? Color.white : Color.black).opacity(on ? (dark ? (strong ? 0.10 : 0.07) : (strong ? 0.055 : 0.04)) : 0))
            .overlay(RoundedRectangle(cornerRadius: 6)
                .strokeBorder((dark ? Color.white : Color.black).opacity(on ? 0.07 : 0), lineWidth: 0.5))
    }
}

/// A view's frame in the taskbar (for placing labels and window previews above it).
struct FrameReader: View {
    @Binding var frame: CGRect
    var body: some View {
        GeometryReader { geo in
            Color.clear.onAppear { frame = geo.frame(in: .global) }.onChange(of: geo.frame(in: .global)) { frame = $0 }
        }
    }
}

/// The name above a taskbar icon you point at, for the Start button and items without a window preview (a pinned app
/// that isn't running, a file, a folder). Tooltips of its own: macOS shows a window's tooltips only while its app is
/// in front, and the taskbar never makes HomePad the app in front.
final class TaskbarLabel {
    static let shared = TaskbarLabel()
    private var panel: NSPanel?
    private var pending: DispatchWorkItem?

    /// `text` nil: the pointer left. The label appears after a short rest, as tooltips do.
    func hover(_ text: String?, over rect: NSRect?) {
        pending?.cancel()
        guard let text, let rect, TaskbarDrag.shared.item == nil else { panel?.orderOut(nil); return }
        let work = DispatchWorkItem { [weak self] in self?.show(text, over: rect) }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
    }

    private func show(_ text: String, over rect: NSRect) {
        let host = NSHostingView(rootView: TaskbarLabelView(text: text).localized())
        let size = host.fittingSize
        let panel = self.panel ?? {
            let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 2)
            p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.ignoresMouseEvents = true
            self.panel = p
            return p
        }()
        panel.contentView = host
        var origin = NSPoint(x: rect.midX - size.width / 2, y: rect.maxY + 10)
        if let screen = NSScreen.screens.first {
            origin.x = min(max(origin.x, screen.frame.minX + 4), screen.frame.maxX - size.width - 4)
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
    }
}

private struct TaskbarLabelView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .windowBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.15), radius: 4, y: 1)
            .padding(8)             // room for the shadow
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
        // Nothing behind the icons while one is dragged, and the dragged one's place stays empty, as on Windows.
        .background(TaskbarHighlight(on: drag.item == nil && (hovering || active), strong: active))
        .opacity(drag.item == url ? 0 : 1)
        .background(FrameReader(frame: $frame))
        .contentShape(Rectangle())
        .onHover { inside in
            hovering = inside
            guard drag.item == nil else { return }
            // A running app shows its windows instead.
            TaskbarLabel.shared.hover(inside && app == nil ? IconCache.name(for: url) : nil, over: Taskbar.shared.screenRect(frame))
            if inside, let app {                 // so its menu is current by the time it's right-clicked
                ClosableWindows.shared.refresh()
                AppMenus.shared.refresh(app)
            }
            WindowPreviewController.shared.hover(app: app, over: inside && app != nil, tile: .zero,
                                                 screenTile: Taskbar.shared.screenRect(frame))
        }
        .onTapGesture {
            WindowPreviewController.shared.hideNow()
            TaskbarLabel.shared.hover(nil, over: nil)
            if let app, app.isActive {
                Launcher.hide(url)
            } else {
                activateSelf()          // the taskbar never makes HomePad active, and macOS lets only the active app hand over
                Launcher.open(url)
            }
        }
        .onDrag({
            TaskbarLabel.shared.hover(nil, over: nil)
            TaskbarDrag.shared.begin(url)
            return RunningDrag.provider(for: url)
        }, preview: {
            // Just the icon in the air, without the square behind it.
            Image(nsImage: IconCache.icon(for: url)).resizable().interpolation(.high).frame(width: 30, height: 30)
        })
        .onDrop(of: [RunningDrag.type] + TaskbarFileDrop.types, delegate: TaskbarDropDelegate(target: url))
        .contextMenu { AppTileMenu(url: url, isRunning: app != nil, onTaskbar: true) }
    }
}
