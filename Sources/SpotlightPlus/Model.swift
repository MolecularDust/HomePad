import AppKit
import UniformTypeIdentifiers

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
}

final class CategoryStore: ObservableObject {
    static let shared = CategoryStore()
    /// The first category is Essentials: it can be renamed but never deleted.
    @Published private(set) var categories: [Category] = []
    private let key = "categories"

    private init() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: key),
           let saved = try? JSONDecoder().decode([Category].self, from: data), !saved.isEmpty {
            categories = saved
        } else {
            // First launch (or upgrade from the single pinned list): everything goes into Essentials.
            let paths = d.stringArray(forKey: "pinnedPaths") ?? DockImporter.pinnedApps().map(\.path)
            categories = [Category(name: "Essentials", paths: paths)]
        }
        for i in categories.indices {
            categories[i].paths = categories[i].paths.filter { FileManager.default.fileExists(atPath: $0) }
        }
        save()
    }

    var essentialsID: UUID { categories[0].id }

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

    func shift(_ url: URL, by delta: Int) {
        guard let loc = location(of: url) else { return }
        let count = urls(in: loc.category).count
        move(url, toCategory: loc.category, at: max(0, min(count - 1, loc.index + delta)))
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

    /// Deleting a category moves its apps to Essentials.
    func delete(_ id: UUID) {
        guard id != essentialsID, let i = categories.firstIndex(where: { $0.id == id }) else { return }
        let paths = categories[i].paths
        categories.remove(at: i)
        categories[0].paths.append(contentsOf: paths)
        save()
    }

    func replaceWithDock() {
        let dock = DockImporter.pinnedApps().map(\.path)
        for i in categories.indices { categories[i].paths.removeAll { dock.contains($0) } }
        categories[0].paths = dock
        save()
    }

    private func insert(_ path: String, in id: UUID, at index: Int?) {
        let i = categories.firstIndex { $0.id == id } ?? 0
        let at = min(index ?? categories[i].paths.count, categories[i].paths.count)
        categories[i].paths.insert(path, at: at)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Running apps (for the "running" dot and the Running section)

final class RunningApps: ObservableObject {
    static let shared = RunningApps()
    @Published private(set) var apps: [NSRunningApplication] = []

    private init() {
        refresh()
        let nc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification] {
            nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.refresh() }
        }
    }

    func refresh() {
        let me = ProcessInfo.processInfo.processIdentifier
        apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.bundleURL != nil && $0.processIdentifier != me
        }
    }

    func app(for url: URL) -> NSRunningApplication? {
        let path = normalized(url).path
        return apps.first { $0.bundleURL.map { normalized($0).path } == path }
    }

    func isRunning(_ url: URL) -> Bool { app(for: url) != nil }
}

// MARK: - Opening things

enum Launcher {
    static func open(_ url: URL) {
        PanelController.shared.hide(restoreFocus: false)
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

    static func reveal(_ url: URL) {
        PanelController.shared.hide(restoreFocus: false)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func quit(_ url: URL) {
        RunningApps.shared.app(for: url)?.terminate()
    }

    static func closeWindows(_ url: URL) {
        if let app = RunningApps.shared.app(for: url) { WindowCatalog.closeWindows(of: app) }
    }

    /// Shows the app picker for a category (Essentials by default). The panel stays visible behind it.
    static func chooseAppsToPin(to category: UUID? = nil) {
        DispatchQueue.main.async { AppPicker.show(for: category) }
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
    private static var cache: [String: NSImage] = [:]

    static func icon(for url: URL) -> NSImage {
        guard url.isFileURL else {
            return NSImage(systemSymbolName: "globe", accessibilityDescription: nil) ?? NSImage()
        }
        if let cached = cache[url.path] { return cached }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        cache[url.path] = image
        return image
    }

    static func name(for url: URL) -> String {
        let name = FileManager.default.displayName(atPath: url.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
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

    static func setHidden(_ hidden: Bool) {
        if hidden {
            run("/usr/bin/defaults", "write", "com.apple.dock", "autohide", "-bool", "true")
            run("/usr/bin/defaults", "write", "com.apple.dock", "autohide-delay", "-float", "1000")
        } else {
            run("/usr/bin/defaults", "write", "com.apple.dock", "autohide", "-bool", "false")
            run("/usr/bin/defaults", "delete", "com.apple.dock", "autohide-delay")
        }
        run("/usr/bin/killall", "Dock") // the Dock relaunches itself with the new settings
    }

    private static func run(_ tool: String, _ args: String...) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        try? p.run()
        p.waitUntilExit()
    }
}
