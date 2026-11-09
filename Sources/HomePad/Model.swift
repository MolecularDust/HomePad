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
    /// File paths, and folders as `FolderRef` keys ("homepad-folder:<id>").
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

/// A folder of tiles inside a category, as in the Windows Start menu: its tile shows the first four, a click opens
/// it. It holds apps and files, not other folders.
struct Folder: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var paths: [String]
}

/// A folder stands in a category's list (and as a tile) by a URL of its own: "homepad-folder:<id>".
enum FolderRef {
    static let scheme = "homepad-folder"

    static func url(_ id: UUID) -> URL { URL(string: "\(scheme):\(id.uuidString)")! }

    static func id(_ url: URL) -> UUID? {
        guard url.scheme == scheme else { return nil }
        return UUID(uuidString: String(url.absoluteString.dropFirst(scheme.count + 1)))
    }

    static func id(key: String) -> UUID? {
        key.hasPrefix(scheme + ":") ? UUID(uuidString: String(key.dropFirst(scheme.count + 1))) : nil
    }
}

/// How an item is written in a list: a file by its path, a folder by its reference.
func itemKey(_ url: URL) -> String { FolderRef.id(url) != nil ? url.absoluteString : normalized(url).path }

func itemURL(_ key: String) -> URL { FolderRef.id(key: key).map(FolderRef.url) ?? URL(fileURLWithPath: key) }

/// Where an item sits: straight in a category, or in a folder.
enum Container: Equatable {
    case category(UUID)
    case folder(UUID)
}

final class CategoryStore: ObservableObject {
    static let shared = CategoryStore()
    /// The first category is Essentials: it can be renamed but never deleted.
    @Published private(set) var categories: [Category] = []
    @Published private(set) var folders: [Folder] = []
    /// Where the Running section sits among the categories: just above this one, or at the end when nil. Kept as a
    /// neighbour rather than a number so that a new category (added at the end) lands above Running when Running is
    /// last, and below it when Running was moved higher.
    @Published private(set) var runningAbove: UUID?
    private let key = "categories"
    private let foldersKey = "folders"
    private let runningKey = "runningAbove"
    /// While a tile is being dragged, a folder emptied down to one item (or none) stays a folder, so the drag can still
    /// put the item back (Esc); it is tidied when the drag ends.
    var holdsFolders = false

    /// Stands for the Running section in the row order, next to the categories' own ids.
    static let runningID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private init() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: key),
           let saved = try? JSONDecoder().decode([Category].self, from: data), !saved.isEmpty {
            categories = saved
        } else if let paths = d.stringArray(forKey: "pinnedPaths") {
            // Upgrade from the single pinned list: everything goes into Essentials.
            categories = [Category(name: L("Essentials"), paths: paths, isEssentials: true)]
        } else {
            // The very first run: the Dock's apps in Essentials, plus a "Files" category with the Trash and
            // Downloads, like the right end of the Dock. Only ever created here, so deleting it keeps it deleted.
            categories = [Category(name: L("Essentials"), paths: DockImporter.pinnedApps().map(\.path), isEssentials: true)]
            if let files = Self.filesCategory(avoiding: categories) { categories.append(files) }
        }
        if let data = d.data(forKey: foldersKey), let saved = try? JSONDecoder().decode([Folder].self, from: data) {
            folders = saved
        }
        // Gone from the disk: unpinned. Folders aren't on the disk, so they stay.
        let present = { (key: String) in FolderRef.id(key: key) != nil || itemExists(atPath: key) }
        for i in categories.indices { categories[i].paths = categories[i].paths.filter(present) }
        for i in folders.indices { folders[i].paths = folders[i].paths.filter(present) }
        if !categories.contains(where: \.isEssentials) { categories[0].isEssentials = true }   // saved before it existed
        // The first category keeps its default name in the current language, until the user renames it.
        if let i = categories.firstIndex(where: \.isEssentials), Localization.defaultNames(for: "Essentials").contains(categories[i].name) {
            categories[i].name = L("Essentials")
        }
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
        return paths.isEmpty ? nil : Category(name: L("Files"), paths: paths)
    }

    private var essentialsIndex: Int { categories.firstIndex(where: \.isEssentials) ?? 0 }
    var essentialsID: UUID { categories[essentialsIndex].id }
    var essentialsName: String { categories[essentialsIndex].name }

    /// A category's tiles, folders included.
    func urls(in id: UUID) -> [URL] {
        (categories.first { $0.id == id }?.paths ?? []).map(itemURL)
    }

    // MARK: Lists, whether a category's or a folder's

    private func paths(of container: Container) -> [String] {
        switch container {
        case .category(let id): return categories.first { $0.id == id }?.paths ?? []
        case .folder(let id): return folders.first { $0.id == id }?.paths ?? []
        }
    }

    private func setPaths(_ paths: [String], of container: Container) {
        switch container {
        case .category(let id): if let i = categories.firstIndex(where: { $0.id == id }) { categories[i].paths = paths }
        case .folder(let id): if let i = folders.firstIndex(where: { $0.id == id }) { folders[i].paths = paths }
        }
    }

    private func exists(_ container: Container) -> Bool {
        switch container {
        case .category(let id): return categories.contains { $0.id == id }
        case .folder(let id): return folders.contains { $0.id == id }
        }
    }

    /// Takes an item out of every list (it is only ever in one).
    private func detach(_ key: String) {
        for i in categories.indices { categories[i].paths.removeAll { $0 == key } }
        for i in folders.indices { folders[i].paths.removeAll { $0 == key } }
    }

    private func insert(_ key: String, in container: Container, at index: Int?) {
        let target = exists(container) ? container : .category(essentialsID)
        var list = paths(of: target)
        list.insert(key, at: min(max(index ?? list.count, 0), list.count))
        setPaths(list, of: target)
    }

    func contains(_ url: URL) -> Bool { location(of: url) != nil }

    func location(of url: URL) -> (container: Container, index: Int)? {
        let key = itemKey(url)
        for c in categories { if let i = c.paths.firstIndex(of: key) { return (.category(c.id), i) } }
        for f in folders { if let i = f.paths.firstIndex(of: key) { return (.folder(f.id), i) } }
        return nil
    }

    /// The category an item is shown in: its own, or the one holding its folder.
    func category(of url: URL) -> UUID? {
        switch location(of: url)?.container {
        case .category(let id): return id
        case .folder(let id): return category(of: FolderRef.url(id))
        case nil: return nil
        }
    }

    /// Adds to a category (Essentials by default). An app lives in one place at a time.
    func add(_ url: URL, to id: UUID? = nil, at index: Int? = nil) {
        guard !contains(url) else { return }
        insert(itemKey(url), in: .category(id ?? essentialsID), at: index)
        save()
    }

    /// Unpins an item. A folder goes with everything in it.
    func remove(_ url: URL) {
        detach(itemKey(url))
        if let id = FolderRef.id(url) { folders.removeAll { $0.id == id } }
        save()
    }

    func move(_ url: URL, toCategory id: UUID, at index: Int? = nil) { move(url, to: .category(id), at: index) }

    /// Moves an item to a place in a category or a folder (folders don't go into folders).
    func move(_ url: URL, to container: Container, at index: Int? = nil) {
        let key = itemKey(url)
        guard contains(url), exists(container) else { return }
        if case .folder = container, FolderRef.id(url) != nil { return }
        detach(key)
        insert(key, in: container, at: index)
        save()
    }

    // MARK: Folders

    func folder(_ id: UUID) -> Folder? { folders.first { $0.id == id } }

    func urls(inFolder id: UUID) -> [URL] { (folder(id)?.paths ?? []).map(itemURL) }

    /// Dropping one tile onto another: onto a folder, it goes in; onto a tile in a category, the two become a folder
    /// in that tile's place; onto a tile already in a folder, it joins that folder. Returns the folder.
    @discardableResult
    func merge(_ dragged: URL, onto target: URL) -> UUID? {
        let draggedKey = itemKey(dragged), targetKey = itemKey(target)
        guard draggedKey != targetKey, FolderRef.id(dragged) == nil, contains(dragged) else { return nil }
        if let id = FolderRef.id(target) {
            move(dragged, to: .folder(id))
            return id
        }
        guard let place = location(of: target) else { return nil }
        if case .folder(let id) = place.container {
            move(dragged, to: .folder(id), at: place.index + 1)
            return id
        }
        let folder = Folder(name: L("Folder"), paths: [targetKey, draggedKey])
        detach(draggedKey)
        guard let index = paths(of: place.container).firstIndex(of: targetKey) else { return nil }
        var list = paths(of: place.container)
        list[index] = FolderRef.url(folder.id).absoluteString
        folders.append(folder)
        setPaths(list, of: place.container)
        save()
        return folder.id
    }

    func renameFolder(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let i = folders.firstIndex(where: { $0.id == id }), !trimmed.isEmpty, folders[i].name != trimmed else { return }
        folders[i].name = trimmed
        save()
    }

    /// The folder goes; its items take its place in the category, in their order.
    func ungroup(_ id: UUID) {
        guard let folder = folder(id) else { return }
        replace(FolderRef.url(id).absoluteString, with: folder.paths)
        folders.removeAll { $0.id == id }
        save()
    }

    /// Takes an item out of its folder and puts it just after the folder.
    func takeOutOfFolder(_ url: URL) {
        guard case .folder(let id)? = location(of: url)?.container,
              let place = location(of: FolderRef.url(id)) else { return }
        move(url, to: place.container, at: place.index + 1)
    }

    private func replace(_ key: String, with keys: [String]) {
        for i in categories.indices {
            if let at = categories[i].paths.firstIndex(of: key) { categories[i].paths.replaceSubrange(at...at, with: keys) }
        }
    }

    /// As in Windows, a folder left with one item becomes that item again, and an empty one goes. Folders no category
    /// shows (its category was deleted) go too, and so do references to folders that no longer exist.
    private func tidyFolders() {
        let shown = Set(categories.flatMap(\.paths).compactMap { FolderRef.id(key: $0) })
        folders.removeAll { !shown.contains($0.id) }
        let known = Set(folders.map(\.id))
        for i in categories.indices {
            categories[i].paths.removeAll { key in FolderRef.id(key: key).map { !known.contains($0) } ?? false }
        }
        guard !holdsFolders else { return }
        for folder in folders where folder.paths.count <= 1 {
            replace(FolderRef.url(folder.id).absoluteString, with: folder.paths)
            folders.removeAll { $0.id == folder.id }
        }
    }

    /// The drag is over: tidy what it left (see `holdsFolders`).
    func endHoldingFolders() {
        guard holdsFolders else { return }
        holdsFolders = false
        save()
    }

    // MARK: Categories

    @discardableResult
    func addCategory(named name: String) -> UUID {
        let category = Category(name: name)
        categories.append(category)
        save()
        return category.id
    }

    /// Items in alphabetical order by the name their tile shows (a folder by its own name, among the rest). Items with
    /// the same name keep their order.
    static func alphabetical(_ keys: [String]) -> [String] {
        keys.enumerated()
            .map { (index: $0.offset, key: $0.element, name: IconCache.name(for: itemURL($0.element))) }
            .sorted {
                let order = $0.name.localizedCaseInsensitiveCompare($1.name)
                return order == .orderedSame ? $0.index < $1.index : order == .orderedAscending
            }
            .map(\.key)
    }

    func isSortedAlphabetically(_ id: UUID) -> Bool {
        guard let paths = categories.first(where: { $0.id == id })?.paths else { return true }
        return Self.alphabetical(paths) == paths
    }

    /// Puts a category's tiles in alphabetical order. The tiles inside its folders keep theirs.
    func sortAlphabetically(_ id: UUID) {
        guard let i = categories.firstIndex(where: { $0.id == id }) else { return }
        let sorted = Self.alphabetical(categories[i].paths)
        guard sorted != categories[i].paths else { return }
        categories[i].paths = sorted
        save()
    }

    func rename(_ id: UUID, to name: String) {
        guard let i = categories.firstIndex(where: { $0.id == id }) else { return }
        categories[i].name = name
        save()
    }

    /// Deleting a category unpins everything in it too, its folders included (the apps and files themselves are
    /// untouched).
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
        for i in folders.indices { folders[i].paths.removeAll { dock.contains($0) } }
        categories[essentialsIndex].paths = dock
        save()
    }

    private func save() {
        tidyFolders()
        if let data = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(data, forKey: key)
        }
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(data, forKey: foldersKey)
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
        if let id = FolderRef.id(url) { FolderPopup.shared.open(id); return }
        guard url.isFileURL, let app = RunningApps.shared.app(for: url) else {
            PanelController.shared.hide(restoreFocus: false)
            openNow(url)
            return
        }
        PanelController.shared.vanish()
        // This Space comes first, as in the Dock: a window showing here → the app comes forward with it; only
        // minimised windows here → the most recent comes back; no window here at all → go to another Space where it
        // has some. The quick check (window server only) settles the usual case; asking the app itself, which can
        // take a few hundred ms and is the only way to find minimised windows, happens when nothing shows here.
        let pid = app.processIdentifier
        DispatchQueue.global(qos: .userInteractive).async {
            let quick = WindowCatalog.realWindows(for: pid, askingApp: false)
            var target: WindowCatalog.RealWindow?
            if !quick.contains(where: { !$0.onOtherSpace }) {
                let all = WindowCatalog.realWindows(for: pid)
                target = all.first(where: \.minimisedHere) ?? all.first(where: \.onOtherSpace)
            }
            DispatchQueue.main.async {
                if let target {
                    WindowCatalog.focus(AppWindow(id: target.id, title: "", frame: target.frame, onOtherSpace: target.onOtherSpace), of: app)
                } else {
                    // While HomePad is still the active app (see `vanish`), so macOS lets it bring this one forward.
                    // Once only: a second request (the "open app" one the Dock uses) made macOS activate it again, and
                    // closing the panel before that settled put the previous app in front for a moment (a flicker).
                    // The panel closes by itself once this app is in front. The "open app" request is only for an
                    // app with no window at all, which then opens a new one.
                    app.activate(options: [.activateAllWindows])
                    if quick.isEmpty && !app.isHidden { openNow(url) }
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

    /// Asks first, then has Finder empty the Trash, as the Dock does: every drive's Trash, locked items and Finder's
    /// own sound included. The first time, macOS asks whether HomePad may control Finder.
    static func emptyTrash() {
        let confirmed = PanelController.shared.keepVisible { () -> Bool in
            let alert = NSAlert()
            alert.messageText = L("Empty the ⟦Trash⟧?")
            alert.informativeText = L("The items in the ⟦Trash⟧ will be erased permanently. You can't undo this action.")
            alert.addButton(withTitle: L("Empty ⟦Trash⟧"))
            alert.addButton(withTitle: L("Cancel"))
            return alert.runModal() == .alertFirstButtonReturn
        }
        guard confirmed else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: "tell application id \"com.apple.finder\" to empty trash")?.executeAndReturnError(&error)
            DispatchQueue.main.async {
                IconCache.trashChanged()
                guard let error else { return }
                let notAllowed = (error[NSAppleScript.errorNumber] as? Int) == -1743
                PanelController.shared.keepVisible {
                    let alert = NSAlert()
                    alert.messageText = notAllowed ? L("HomePad isn't allowed to control ⟦Finder⟧") : L("The ⟦Trash⟧ couldn't be emptied")
                    alert.informativeText = notAllowed
                        ? L("HomePad asks ⟦Finder⟧ to empty the ⟦Trash⟧, as the ⟦Dock⟧ does. Turn on ⟦Finder⟧ under HomePad in ⟦System Settings⟧ › ⟦Privacy & Security⟧ › ⟦Automation⟧.")
                        : (error[NSAppleScript.errorMessage] as? String ?? L("⟦Finder⟧ reported an error."))
                    alert.addButton(withTitle: notAllowed ? L("Open ⟦System Settings⟧") : L("OK"))
                    if notAllowed { alert.addButton(withTitle: L("Cancel")) }
                    if alert.runModal() == .alertFirstButtonReturn, notAllowed { Permissions.openSettings("Privacy_Automation") }
                }
            }
        }
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
            if let name = TextPrompt.ask(title: L("New Category"), message: L("Name the category, for example Browsers."),
                                         button: L("Add")) {
                CategoryStore.shared.addCategory(named: name)
            }
        }
    }

    static func renameCategory(_ category: Category) {
        DispatchQueue.main.async {
            if let name = TextPrompt.ask(title: L("Rename Category"), initial: category.name, button: L("Rename")) {
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

    /// As last checked (the Trash tile's icon keeps this current).
    static var trashIsFull: Bool { trashFull ?? false }

    /// The Trash changed (it was just emptied): check it again on the next draw.
    static func trashChanged() {
        trashFull = trashHasItems()
        trashChecked = Date()
        CategoryStore.shared.objectWillChange.send()
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
        if let id = FolderRef.id(url) { return CategoryStore.shared.folder(id)?.name ?? L("Folder") }   // renamed at will: not cached
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

    /// Brings the Dock back and waits until that's done (for uninstalling, just before HomePad quits).
    static func showNow() { apply(false) }

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

    /// HomePad + Dock mode: the Dock shown, with HomePad kept in it (added at the right end of the apps if it isn't
    /// there; you can move it from there). Restarts the Dock once, only if something changed.
    static func showWithHomePad() {
        DispatchQueue.global(qos: .userInitiated).async {
            var changed = false
            if isHidden {
                run("/usr/bin/defaults", "write", "com.apple.dock", "autohide", "-bool", "false")
                run("/usr/bin/defaults", "delete", "com.apple.dock", "autohide-delay")
                changed = true
            }
            if !DockIcon.isKeptInDock {
                let url = Bundle.main.bundleURL.absoluteString
                let tile = "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>\(url)</string>"
                    + "<key>_CFURLStringType</key><integer>15</integer></dict><key>file-label</key><string>HomePad</string></dict>"
                    + "<key>tile-type</key><string>file-tile</string></dict>"
                run("/usr/bin/defaults", "write", "com.apple.dock", "persistent-apps", "-array-add", tile)
                changed = true
            }
            if changed { run("/usr/bin/killall", "Dock") }
        }
    }

    private static func run(_ tool: String, _ args: String...) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        try? p.run()
        p.waitUntilExit()
    }
}
