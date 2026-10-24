import AppKit
import Carbon.HIToolbox

/// The filters next to the search field, as in Spotlight. ⌘1 to ⌘4 switch to them.
enum SearchScope: CaseIterable {
    case all, apps, files, actions, clipboard

    static let filters: [SearchScope] = [.apps, .files, .actions, .clipboard]

    var symbol: String {
        switch self {
        case .all: return "magnifyingglass"
        case .apps: return "square.grid.2x2"
        case .files: return "folder"
        case .actions: return "square.stack.3d.up"
        case .clipboard: return "doc.on.doc"
        }
    }

    var title: String {
        switch self {
        case .all: return "Everything"
        case .apps: return "Apps"
        case .files: return "Files and Folders"
        case .actions: return "Shortcuts"
        case .clipboard: return "Clipboard History"
        }
    }

    var placeholder: String {
        switch self {
        case .all: return "SpotlightPlus Search"
        case .apps: return "Search apps"
        case .files: return "Search files and folders"
        case .actions: return "Search your Shortcuts"
        case .clipboard: return "Search clipboard history"
        }
    }

    var emptyMessage: String {
        switch self {
        case .all: return ""
        case .apps: return "No apps found."
        case .files: return "No files or folders found."
        case .actions: return "No Shortcuts found. Create some in the Shortcuts app."
        case .clipboard: return ClipboardHistory.enabled ? "Nothing copied recently." : "Clipboard history is turned off in Settings."
        }
    }

    /// ⌘1 ... ⌘4
    static func forKeyCode(_ code: Int) -> SearchScope? {
        switch code {
        case kVK_ANSI_1: return .apps
        case kVK_ANSI_2: return .files
        case kVK_ANSI_3: return .actions
        case kVK_ANSI_4: return .clipboard
        default: return nil
        }
    }
}

struct SearchResult: Identifiable, Hashable {
    enum Section: Int { case calculator, apps, files, action, clipboard, web
        var title: String {
            switch self {
            case .calculator: return "Calculator"
            case .apps: return "Apps"
            case .files: return "Documents & Folders"
            case .action: return "Shortcuts"
            case .clipboard: return "Clipboard History"
            case .web: return "Web"
            }
        }
    }
    let url: URL
    let name: String
    let subtitle: String
    let section: Section
    /// Set on a calculator answer or clipboard item: what Return or the copy button puts on the clipboard.
    var copyText: String?
    /// Set on a Shortcut: the name to run.
    var actionName: String?
    /// An SF Symbol to show instead of a file icon.
    var symbol: String?
    /// A small app icon shown on the corner of the icon (the app a clipboard item was copied from).
    var badgeURL: URL?
    var id: URL { url }
}

/// Searches the same index Spotlight uses (NSMetadataQuery), as you type, and fills the other filters.
final class SearchEngine: ObservableObject {
    static let shared = SearchEngine()
    @Published private(set) var results: [SearchResult] = []

    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []
    private var pending: DispatchWorkItem?
    private var text = ""
    private var typed = ""
    private var scope = SearchScope.all

    func search(_ raw: String, scope: SearchScope) {
        pending?.cancel()
        stop()
        self.scope = scope
        // '*' and '?' are wildcards in Spotlight queries; drop them from user input.
        let cleaned = raw.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "?", with: "")
        text = cleaned
        typed = raw

        switch scope {
        case .apps: results = appResults(); return
        case .clipboard: results = clipboardResults(); return
        case .actions: showActions(); return
        case .files:
            let work = DispatchWorkItem { [weak self] in self?.start(cleaned) }
            pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + (cleaned.isEmpty ? 0 : 0.08), execute: work)
            return
        case .all: break
        }

        guard !cleaned.isEmpty else { results = []; return }

        // The web search gets what was typed (the wildcard stripping is only for the Spotlight index query).
        let webText = raw.trimmingCharacters(in: .whitespaces)
        let calculation = calculatorResults()
        if !calculation.isEmpty {
            results = calculation + [webResult(webText)]      // a sum isn't a file search
            return
        }
        results = [webResult(webText)] + results.filter { $0.section == .apps || $0.section == .files }
        let work = DispatchWorkItem { [weak self] in self?.start(cleaned) }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work) // light debounce
    }

    // MARK: Spotlight index

    private func start(_ text: String) {
        let q = NSMetadataQuery()
        if scope == .files && text.isEmpty {
            // Nothing typed: what you opened lately, newest first.
            // Opened in the last 30 days, or a document changed in the last 7.
            let opened = Date().addingTimeInterval(-30 * 24 * 3600) as NSDate
            let changed = Date().addingTimeInterval(-7 * 24 * 3600) as NSDate
            q.predicate = NSPredicate(format: "kMDItemLastUsedDate >= %@ OR (kMDItemContentModificationDate >= %@ AND kMDItemContentTypeTree == 'public.content')", opened, changed)
            q.sortDescriptors = [NSSortDescriptor(key: "kMDItemContentModificationDate", ascending: false)]
        } else {
            q.predicate = NSPredicate(format: "%K LIKE[cd] %@", NSMetadataItemDisplayNameKey, "*\(text)*")
        }
        q.searchScopes = [NSMetadataQueryLocalComputerScope]
        let nc = NotificationCenter.default
        for name in [Notification.Name.NSMetadataQueryDidFinishGathering,
                     Notification.Name.NSMetadataQueryDidUpdate] {
            observers.append(nc.addObserver(forName: name, object: q, queue: .main) { [weak self] _ in
                self?.collect()
            })
        }
        query = q
        q.start()
    }

    private func stop() {
        query?.stop()
        query = nil
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers = []
    }

    private func collect() {
        guard let q = query else { return }
        q.disableUpdates()
        defer { q.enableUpdates() }

        let needle = text.lowercased()
        var apps: [(SearchResult, Int, Date)] = []
        var files: [(SearchResult, Int, Date)] = []
        var seen = Set<String>()

        let recents = scope == .files && text.isEmpty
        // Folders that are always "recent" because the system touches them.
        let systemFolders: Set<String> = [NSHomeDirectory(), "/Users", "/Applications", "/Library", "/System", "/Volumes"]
        for i in 0..<min(q.resultCount, recents ? 2000 : 500) {
            guard let item = q.result(at: i) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  seen.insert(path).inserted else { continue }
            let type = item.value(forAttribute: "kMDItemContentType") as? String ?? ""
            let isApp = type == "com.apple.application-bundle"
            if isApp && scope == .files { continue }
            // Skip system/cache noise for files; apps can live anywhere.
            if !isApp && (path.contains("/Library/") || path.contains("/.")) { continue }
            if recents && systemFolders.contains(path) { continue }

            let url = URL(fileURLWithPath: path)
            var name = item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String ?? url.lastPathComponent
            if name.hasSuffix(".app") { name = String(name.dropLast(4)) }
            let lower = name.lowercased()
            let rank = lower.hasPrefix(needle) ? 0
                : lower.split(separator: " ").contains { $0.hasPrefix(needle) } ? 1 : 2
            let opened = item.value(forAttribute: "kMDItemLastUsedDate") as? Date ?? .distantPast
            let changed = item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date ?? .distantPast
            let used = max(opened, changed)
            let parent = (url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
            let result = SearchResult(url: url, name: name, subtitle: parent, section: isApp ? .apps : .files)
            if isApp { apps.append((result, rank, used)) } else { files.append((result, rank, used)) }
        }

        func best(_ list: [(SearchResult, Int, Date)], _ n: Int) -> [SearchResult] {
            list.sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.2 > $1.2 }.prefix(n).map(\.0)
        }
        if scope == .files {
            results = best(files, 40)
        } else {
            results = best(apps, 6) + best(files, 10) + [webResult(typed.trimmingCharacters(in: .whitespaces))]
        }
        let state = PanelState.shared
        if state.selection >= results.count { state.selection = 0 }
    }

    // MARK: Other filters

    /// Every installed app, or the ones matching what's typed.
    private func appResults() -> [SearchResult] {
        let needle = text.lowercased()
        return InstalledApps.cached(refresh: true).compactMap { url -> (SearchResult, Int)? in
            let name = IconCache.name(for: url)
            let lower = name.lowercased()
            if !needle.isEmpty && !lower.contains(needle) { return nil }
            let rank = needle.isEmpty || lower.hasPrefix(needle) ? 0 : 1
            let parent = (url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
            return (SearchResult(url: url, name: name, subtitle: parent, section: .apps), rank)
        }
        .sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0.name.localizedCaseInsensitiveCompare($1.0.name) == .orderedAscending }
        .map(\.0)
    }

    private func clipboardResults() -> [SearchResult] {
        let needle = text.lowercased()
        let time = DateFormatter()
        time.timeStyle = .short
        time.dateStyle = .none
        let day = DateFormatter()
        day.dateStyle = .short
        day.timeStyle = .short
        return ClipboardHistory.shared.recent
            .filter { needle.isEmpty || $0.text.lowercased().contains(needle) }
            .map { item in
                let oneLine = item.text.split(whereSeparator: \.isNewline).joined(separator: " ")
                let shown = oneLine.count > 110 ? String(oneLine.prefix(110)) + "…" : oneLine
                let when = Calendar.current.isDateInToday(item.date) ? time.string(from: item.date) : day.string(from: item.date)
                let app = item.appBundleID.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
                return SearchResult(url: URL(string: "spotlightplus-clipboard://\(item.id.uuidString)")!, name: shown,
                                    subtitle: "Text · Copied \(when)", section: .clipboard, copyText: item.text,
                                    symbol: "doc.text", badgeURL: app)
            }
    }

    /// Shortcuts: the cached list at once, then the fresh one.
    private func showActions() {
        results = actionResults(ShortcutsCatalog.cachedNames)
        ShortcutsCatalog.load { [weak self] names in
            guard let self, self.scope == .actions else { return }
            self.results = self.actionResults(names)
            let state = PanelState.shared
            if state.selection >= self.results.count { state.selection = 0 }
        }
    }

    private func actionResults(_ names: [String]) -> [SearchResult] {
        let needle = text.lowercased()
        return names.filter { needle.isEmpty || $0.lowercased().contains(needle) }.map { name in
            var components = URLComponents(string: "spotlightplus-action://run")!
            components.queryItems = [URLQueryItem(name: "name", value: name)]
            return SearchResult(url: components.url!, name: name, subtitle: "Shortcut", section: .action,
                                actionName: name, symbol: "square.stack.3d.up")
        }
    }

    /// Arithmetic typed into the field gets an answer card first, as in Spotlight.
    private func calculatorResults() -> [SearchResult] {
        guard let answer = Calculator.evaluate(typed) else { return [] }
        return [SearchResult(url: URL(string: "spotlightplus-calculator://answer")!, name: answer.value,
                             subtitle: answer.expression, section: .calculator, copyText: answer.value)]
    }

    private func webResult(_ text: String) -> SearchResult {
        var c = URLComponents(string: "https://www.google.com/search")!
        c.queryItems = [URLQueryItem(name: "q", value: text)]
        return SearchResult(url: c.url!, name: "Search the web for “\(text)”", subtitle: "Google", section: .web)
    }
}
