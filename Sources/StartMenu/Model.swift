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

// MARK: - Pinned items (your own list, unlimited)

final class PinnedStore: ObservableObject {
    static let shared = PinnedStore()
    @Published private(set) var items: [URL] = []
    private let key = "pinnedPaths"

    private init() {
        if let paths = UserDefaults.standard.stringArray(forKey: key) {
            items = paths.map { URL(fileURLWithPath: $0) }
                .filter { FileManager.default.fileExists(atPath: $0.path) }
        } else {
            items = DockImporter.pinnedApps()   // first launch: copy the Dock
            save()
        }
    }

    func contains(_ url: URL) -> Bool { items.contains { $0.path == normalized(url).path } }

    func add(_ url: URL, at index: Int? = nil) {
        let u = normalized(url)
        guard !contains(u) else { return }
        if let index, index <= items.count { items.insert(u, at: index) } else { items.append(u) }
        save()
    }

    func remove(_ url: URL) {
        items.removeAll { $0.path == normalized(url).path }
        save()
    }

    func move(_ url: URL, to index: Int) {
        guard let from = items.firstIndex(where: { $0.path == url.path }), from != index else { return }
        let item = items.remove(at: from)
        items.insert(item, at: min(index, items.count))
        save()
    }

    func shift(_ url: URL, by delta: Int) {
        guard let from = items.firstIndex(where: { $0.path == url.path }) else { return }
        move(url, to: max(0, min(items.count - 1, from + delta)))
    }

    func replaceWithDock() {
        items = DockImporter.pinnedApps()
        save()
    }

    private func save() {
        UserDefaults.standard.set(items.map(\.path), forKey: key)
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

    /// Shows a file picker for apps to pin. The panel is hidden while the picker is open.
    static func chooseAppsToPin() {
        let pc = PanelController.shared
        pc.suppressAutoHide = true
        pc.hide(restoreFocus: false)
        DispatchQueue.main.async {
            activateSelf()
            let panel = NSOpenPanel()
            panel.title = "Pin Apps to Start"
            panel.prompt = "Pin"
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            panel.allowedContentTypes = [.application]
            panel.directoryURL = URL(fileURLWithPath: "/Applications")
            if panel.runModal() == .OK {
                panel.urls.forEach { PinnedStore.shared.add($0) }
            }
            pc.suppressAutoHide = false
            pc.show()
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
