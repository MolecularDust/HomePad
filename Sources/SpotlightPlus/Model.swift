import AppKit
import UniformTypeIdentifiers

/// False only when the item is really gone. A file in a protected folder (Documents, Desktop, Downloads) that
/// this app isn't allowed to look at reports "no permission", not "missing", and must stay pinned.
func itemExists(atPath path: String) -> Bool {
    do {
        _ = try FileManager.default.attributesOfItem(atPath: path)
        return true
    } catch let error as NSError {
        return !(error.domain == NSCocoaErrorDomain && (error.code == NSFileNoSuchFileError || error.code == NSFileReadNoSuchFileError))
            && !(error.domain == NSPOSIXErrorDomain && error.code == Int(ENOENT))
    }
}

func normalized(_ url: URL) -> URL {
    URL(fileURLWithPath: url.standardizedFileURL.path)
}

// MARK: - Reading the real Dock

enum DockImporter {
    /// Apps pinned in the macOS Dock, in Dock order, with Finder first (as the Dock shows it).
    static func pinnedApps() -> [URL] {
        let domain = "com.apple.dock" as CFString
        CFPreferencesAppSynchronize(domain)
        var urls = [URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")]

        if let items = CFPreferencesCopyAppValue("persistent-apps" as CFString, domain) as? [[String: Any]] {
            for item in items {
                guard let tile = item["tile-data"] as? [String: Any],
                      let file = tile["file-data"] as? [String: Any],
                      let string = file["_CFURLString"] as? String else { continue } // spacers etc.
                let url = string.hasPrefix("file://") ? URL(string: string) : URL(fileURLWithPath: string)
                if let url { urls.append(normalized(url)) }
            }
        }

        var seen = Set<String>()
        return urls.filter { FileManager.default.fileExists(atPath: $0.path) && seen.insert($0.path).inserted }
    }
}

// MARK: - Categories (your own lists, unlimited)

struct Category: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var paths: [String] = []
    /// The category that things are added to by default, and that can't be deleted. It starts out first, but a
    /// category can be dragged above it, so it is marked rather than found by position.
    var isEssentials = false

    init(id: UUID = UUID(), name: String, paths: [String] = [], isEssentials: Bool = false) {
        self.id = id
        self.name = name
        self.paths = paths
        self.isEssentials = isEssentials
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        paths = try values.decode([String].self, forKey: .paths)
        isEssentials = try values.decodeIfPresent(Bool.self, forKey: .isEssentials) ?? false    // saved before it existed
    }
}

final class CategoryStore: ObservableObject {
    static let shared = CategoryStore()
    /// The first category is Essentials: it can be renamed but never deleted.
    @Published private(set) var categories: [Category] = []
    /// Where the Running section sits among the categories: just above this one, or at the end when nil. Kept as a
    /// neighbour rather than a number so that a new category (added at the end) lands above Running when Running is
    /// last, and below it when Running was moved higher.
    @Published private(set) var runningAbove: UUID?
    private let key = "categories"
    private let runningKey = "runningAbove"

    /// Stands for the Running section in the row order, next to the categories' own ids.
    static let runningID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private init() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: key),
           let saved = try? JSONDecoder().decode([Category].self, from: data), !saved.isEmpty {
            categories = saved
        } else if let paths = d.stringArray(forKey: "pinnedPaths") {
            // Upgrade from the single pinned list: everything goes into Essentials.
            categories = [Category(name: "Essentials", paths: paths, isEssentials: true)]
        } else {
            // The very first run: the Dock's apps in Essentials, plus a "Files" category with the Trash and
            // Downloads, like the right end of the Dock. Only ever created here, so deleting it keeps it deleted.
            categories = [Category(name: "Essentials", paths: DockImporter.pinnedApps().map(\.path), isEssentials: true)]
            if let files = Self.filesCategory(avoiding: categories) { categories.append(files) }
        }
        for i in categories.indices {
            categories[i].paths = categories[i].paths.filter { itemExists(atPath: $0) }
        }
        if !categories.contains(where: \.isEssentials) { categories[0].isEssentials = true }   // saved before it existed
        runningAbove = d.string(forKey: runningKey).flatMap(UUID.init(uuidString:))
        save()
    }

    /// Whether the Running section is on screen: it's turned on in Settings and something is running.
    var showsRunning: Bool {
        (UserDefaults.standard.object(forKey: "showRunning") as? Bool ?? true) && !RunningApps.shared.apps.isEmpty
    }

    /// The rows from top to bottom: the categories, with Running in its place among them when it is shown.
    func rows(includingRunning: Bool) -> [UUID] {
        var ids = categories.map(\.id)
        if includingRunning { ids.insert(Self.runningID, at: runningAbove.flatMap { ids.firstIndex(of: $0) } ?? ids.count) }
        return ids
    }

    /// The rows as they are shown right now.
    var visibleRows: [UUID] { rows(includingRunning: showsRunning) }

    /// Puts a row (a category or Running) at a place among the rows on screen, moving the others along.
    func moveRow(_ id: UUID, toIndex index: Int) {
        var ids = visibleRows
        guard let from = ids.firstIndex(of: id), ids.indices.contains(index), from != index else { return }
        ids.insert(ids.remove(at: from), at: index)
        apply(ids)
    }

    /// Moves a row one place up (-1) or down (+1), from its right-click menu.
    func moveRow(_ id: UUID, by offset: Int) {
        guard let from = visibleRows.firstIndex(of: id) else { return }
        moveRow(id, toIndex: from + offset)
    }

    private func apply(_ ids: [UUID]) {
        let byID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        categories = ids.compactMap { byID[$0] }
        if let running = ids.firstIndex(of: Self.runningID) {
            runningAbove = ids.indices.contains(running + 1) ? ids[running + 1] : nil
        }
        save()
    }

    /// The Trash and Downloads (in that order, like the Dock), left out when they are already pinned somewhere.
    static func filesCategory(avoiding existing: [Category]) -> Category? {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path
            ?? NSHomeDirectory() + "/Downloads"
        let paths = [trashURL.path, downloads].filter { path in !existing.contains { $0.paths.contains(path) } }
        return paths.isEmpty ? nil : Category(name: "Files", paths: paths)
    }

    private var essentialsIndex: Int { categories.firstIndex(where: \.isEssentials) ?? 0 }
    var essentialsID: UUID { categories[essentialsIndex].id }
    var essentialsName: String { categories[essentialsIndex].name }

    func urls(in id: UUID) -> [URL] {
        (categories.first { $0.id == id }?.paths ?? []).map { URL(fileURLWithPath: $0) }
    }

    func contains(_ url: URL) -> Bool { location(of: url) != nil }

    func location(of url: URL) -> (category: UUID, index: Int)? {
        let path = normalized(url).path
        for c in categories {
            if let i = c.paths.firstIndex(of: path) { return (c.id, i) }
        }
        return nil
    }

    /// Adds to a category (Essentials by default). An app lives in one category at a time.
    func add(_ url: URL, to id: UUID? = nil, at index: Int? = nil) {
        guard !contains(url) else { return }
        insert(normalized(url).path, in: id ?? essentialsID, at: index)
        save()
    }

    func remove(_ url: URL) {
        let path = normalized(url).path
        for i in categories.indices { categories[i].paths.removeAll { $0 == path } }
        save()
    }

    func move(_ url: URL, toCategory id: UUID, at index: Int? = nil) {
        let path = normalized(url).path
        guard contains(url) else { return }
        for i in categories.indices { categories[i].paths.removeAll { $0 == path } }
        insert(path, in: id, at: index)
        save()
    }

    @discardableResult
    func addCategory(named name: String) -> UUID {
        let category = Category(name: name)
        categories.append(category)
        save()
        return category.id
    }

    func rename(_ id: UUID, to name: String) {
        guard let i = categories.firstIndex(where: { $0.id == id }) else { return }
        categories[i].name = name
        save()
    }

    /// Deleting a category unpins everything in it too (the apps and files themselves are untouched).
    func delete(_ id: UUID) {
        guard id != essentialsID, let i = categories.firstIndex(where: { $0.id == id }) else { return }
        categories.remove(at: i)
        // Running stays where it was: above whatever came after the deleted category.
        if runningAbove == id { runningAbove = categories.indices.contains(i) ? categories[i].id : nil }
        save()
    }

    func replaceWithDock() {
        let dock = DockImporter.pinnedApps().map(\.path)
        for i in categories.indices { categories[i].paths.removeAll { dock.contains($0) } }
        categories[essentialsIndex].paths = dock
        save()
    }

    private func insert(_ path: String, in id: UUID, at index: Int?) {
        let i = categories.firstIndex { $0.id == id } ?? essentialsIndex
        let at = min(index ?? categories[i].paths.count, categories[i].paths.count)
        categories[i].paths.insert(path, at: at)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(data, forKey: key)
        }
        UserDefaults.standard.set(runningAbove?.uuidString, forKey: runningKey)
    }
}

// MARK: - Running apps (for the "running" dot and the Running section)

final class RunningApps: ObservableObject {
    static let shared = RunningApps()
    @Published private(set) var apps: [NSRunningApplication] = []
    private var byPath: [String: NSRunningApplication] = [:]       // every tile asks "is this running?" on each redraw

    private init() {
        refresh()
        let nc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification] {
            nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.refresh() }
        }
    }

    /// Publishes only when the set of running apps really changed, since that redraws every tile.
    func refresh() {
        let me = ProcessInfo.processInfo.processIdentifier
        let current = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.bundleURL != nil && $0.processIdentifier != me
        }
        guard current.map(\.processIdentifier) != apps.map(\.processIdentifier) else { return }
        byPath = Dictionary(current.compactMap { app in app.bundleURL.map { (normalized($0).path, app) } }) { first, _ in first }
        apps = current
    }

    func app(for url: URL) -> NSRunningApplication? { byPath[normalized(url).path] }

    func isRunning(_ url: URL) -> Bool { app(for: url) != nil }
}

/// Apps that were asked to quit and didn't: still running a few seconds later, they get Force Quit in their menu.
final class QuitRequests: ObservableObject {
    static let shared = QuitRequests()
    @Published private(set) var ignored: Set<pid_t> = []
    private static let patience: TimeInterval = 3

    private init() {
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification,
                                                          object: nil, queue: .main) { [weak self] note in
            guard let self, let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self.ignored.remove(app.processIdentifier)
        }
    }

    func watch(_ app: NSRunningApplication) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.patience) { [weak self] in
            guard let self, !app.isTerminated else { return }
            self.ignored.insert(app.processIdentifier)
        }
    }
}

// MARK: - Opening things

enum Launcher {
    static func open(_ url: URL) {
        PanelController.shared.hide(restoreFocus: false)
        guard url.isFileURL, let app = RunningApps.shared.app(for: url) else { openNow(url); return }
        // A running app whose windows are all on other Spaces: go to one of them, as the Dock does. Worked out in the
        // background: the quick check (window server only) settles the usual case; asking the app itself, which can
        // take a few hundred ms, only happens when every window seems to be on another Space.
        let pid = app.processIdentifier
        DispatchQueue.global(qos: .userInteractive).async {
            var windows = WindowCatalog.realWindows(for: pid, askingApp: false)
            if !windows.isEmpty, windows.allSatisfy(\.onOtherSpace) { windows = WindowCatalog.realWindows(for: pid) }
            DispatchQueue.main.async {
                if let first = windows.first, windows.allSatisfy(\.onOtherSpace) {
                    WindowCatalog.focus(AppWindow(id: first.id, title: "", frame: first.frame, onOtherSpace: true), of: app)
                } else {
                    openNow(url)
                }
            }
        }
    }

    private static func openNow(_ url: URL) {
        if url.isFileURL && url.pathExtension == "app" {
            // Launches the app, or brings it forward (and reopens a window) if already running —
            // the same thing clicking a Dock icon does.
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
                if let error { DispatchQueue.main.async { NSAlert(error: error).runModal() } }
            }
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    /// Puts text on the clipboard, e.g. a calculator answer.
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    static func reveal(_ url: URL) {
        PanelController.shared.hide(restoreFocus: false)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Finder can't be quit from here, as in the Dock: quitting it takes the desktop's icons away until it is restarted.
    static func canQuit(_ url: URL) -> Bool {
        RunningApps.shared.app(for: url)?.bundleIdentifier != "com.apple.finder"
    }

    /// Quits the app; with Option held while choosing it, force quits (as in the Dock). An app still running a few
    /// seconds after being asked is remembered, and its menu then offers Force Quit instead.
    static func quit(_ url: URL) {
        guard canQuit(url), let app = RunningApps.shared.app(for: url) else { return }
        if NSEvent.modifierFlags.contains(.option) || QuitRequests.shared.ignored.contains(app.processIdentifier) {
            app.forceTerminate()
            return
        }
        app.terminate()
        QuitRequests.shared.watch(app)
    }

    static func hide(_ url: URL) {
        PanelController.shared.hide(restoreFocus: false)
        RunningApps.shared.app(for: url)?.hide()
    }

    static func closeWindows(_ url: URL) {
        if let app = RunningApps.shared.app(for: url) { WindowCatalog.closeWindows(of: app) }
    }

    /// Shows the app picker for a category (Essentials by default). The panel stays visible behind it.
    static func chooseAppsToPin(to category: UUID? = nil) {
        DispatchQueue.main.async { AppPicker.show(for: category) }
    }

    /// Pins any files or folders, from a browser window styled like Add Apps (with a Trash entry).
    static func chooseFilesToPin(to category: UUID? = nil) {
        DispatchQueue.main.async { FilePicker.show(for: category) }
    }

    static func addCategory() {
        DispatchQueue.main.async {
            if let name = TextPrompt.ask(title: "New Category", message: "Name the category, for example Browsers.",
                                         button: "Add") {
                CategoryStore.shared.addCategory(named: name)
            }
        }
    }

    static func renameCategory(_ category: Category) {
        DispatchQueue.main.async {
            if let name = TextPrompt.ask(title: "Rename Category", initial: category.name, button: "Rename") {
                CategoryStore.shared.rename(category.id, to: name)
            }
        }
    }
}

// MARK: - Icons & names

enum IconCache {
    /// Limited: search results and the file picker show icons of any number of files, and keeping all of them grew
    /// without end. Pinned items are asked for constantly, so they stay.
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 400
        return cache
    }()

    private static var trashFull: Bool?
    private static var trashChecked = Date.distantPast
    private static var trashImages: [Bool: NSImage] = [:]

    static func icon(for url: URL) -> NSImage {
        guard url.isFileURL else {
            return NSImage(systemSymbolName: "globe", accessibilityDescription: nil) ?? NSImage()
        }
        if url.path == trashURL.path { return trashIcon() }
        if let cached = cache.object(forKey: url.path as NSString) { return cached }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        cache.setObject(image, forKey: url.path as NSString)
        return image
    }

    /// The system's trash can, empty or full. Asking the file system for the icon of ~/.Trash returns a plain folder.
    private static func trashIcon() -> NSImage {
        // Looking for one visible item is cheap even when the Trash holds thousands, but it is still a disk access, so
        // after the first time it's done in the background and the tiles are redrawn only if the answer changed.
        if trashFull == nil {
            trashFull = trashHasItems()
            trashChecked = Date()
        } else if Date().timeIntervalSince(trashChecked) > 3 {
            trashChecked = Date()
            DispatchQueue.global(qos: .utility).async {
                let full = trashHasItems()
                DispatchQueue.main.async {
                    guard full != trashFull else { return }
                    trashFull = full
                    CategoryStore.shared.objectWillChange.send()
                }
            }
        }
        let full = trashFull ?? false
        if let image = trashImages[full] { return image }
        let image = NSImage(named: full ? NSImage.trashFullName : NSImage.trashEmptyName) ?? NSWorkspace.shared.icon(forFile: trashURL.path)
        trashImages[full] = image
        return image
    }

    private static func trashHasItems() -> Bool {
        FileManager.default.enumerator(at: trashURL, includingPropertiesForKeys: nil,
                                       options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])?.nextObject() != nil
    }

    private static let names: NSCache<NSString, NSString> = {
        let cache = NSCache<NSString, NSString>()
        cache.countLimit = 2000
        return cache
    }()

    /// Remembered (up to a limit): the file system lookup is slow enough to matter when every tile asks on every redraw.
    static func name(for url: URL) -> String {
        if let known = names.object(forKey: url.path as NSString) { return known as String }
        let display = FileManager.default.displayName(atPath: url.path)
        let name = display.hasSuffix(".app") ? String(display.dropLast(4)) : display
        names.setObject(name as NSString, forKey: url.path as NSString)
        return name
    }
}

// MARK: - Dropped files from Finder

enum FileDrop {
    static func load(_ providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url, url.isFileURL {
                    lock.lock(); urls.append(url); lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) { completion(urls) }
    }
}

// MARK: - Hiding the real Dock

enum DockControl {
    /// True if the Dock is auto-hidden with a very long reveal delay (i.e. effectively never shows).
    static var isHidden: Bool {
        let domain = "com.apple.dock" as CFString
        CFPreferencesAppSynchronize(domain)
        let autohide = CFPreferencesCopyAppValue("autohide" as CFString, domain) as? Bool ?? false
        let delay = CFPreferencesCopyAppValue("autohide-delay" as CFString, domain) as? Double ?? 0
        return autohide && delay >= 100
    }

    /// Runs `defaults` and restarts the Dock in the background: waiting for them froze Settings.
    static func setHidden(_ hidden: Bool) {
        DispatchQueue.global(qos: .userInitiated).async { apply(hidden) }
    }

    /// The very long reveal delay is only read when the Dock starts, so the Dock is restarted. But a Dock that starts
    /// already auto-hidden doesn't always give back the space it took on screen: windows snapped to that edge kept a
    /// gap where the Dock had been. So it restarts with auto-hide off, and auto-hide is then switched on live, the
    /// way System Settings does it, which frees the space.
    private static func apply(_ hidden: Bool) {
        if hidden {
            run("/usr/bin/defaults", "write", "com.apple.dock", "autohide-delay", "-float", "1000")
            run("/usr/bin/defaults", "write", "com.apple.dock", "autohide", "-bool", "false")
        } else {
            run("/usr/bin/defaults", "write", "com.apple.dock", "autohide", "-bool", "false")
            run("/usr/bin/defaults", "delete", "com.apple.dock", "autohide-delay")
        }
        let old = dockPID()
        run("/usr/bin/killall", "Dock") // the Dock relaunches itself with the new settings
        guard hidden else { return }
        // Wait for the new Dock, then switch auto-hide on.
        for _ in 0..<50 where dockPID() == old || dockPID() == nil { Thread.sleep(forTimeInterval: 0.1) }
        Thread.sleep(forTimeInterval: 0.6)
        if let setAutoHide {
            setAutoHide(true)
        } else {
            run("/usr/bin/defaults", "write", "com.apple.dock", "autohide", "-bool", "true")
            run("/usr/bin/killall", "Dock")
        }
    }

    private static func dockPID() -> pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier
    }

    /// The Dock's own switch for auto-hide (a private call in ApplicationServices that System Settings and window
    /// utilities use); looked up at run time, and the plain restart is used if it ever goes away.
    private typealias SetAutoHide = @convention(c) (Bool) -> Void
    private static let setAutoHide = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CoreDockSetAutoHideEnabled")
        .map { unsafeBitCast($0, to: SetAutoHide.self) }

    private static func run(_ tool: String, _ args: String...) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        try? p.run()
        p.waitUntilExit()
    }
}
