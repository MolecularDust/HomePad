import AppKit

struct SearchResult: Identifiable, Hashable {
    enum Section: Int { case apps, files, web
        var title: String {
            switch self {
            case .apps: return "Apps"
            case .files: return "Documents & Folders"
            case .web: return "Web"
            }
        }
    }
    let url: URL
    let name: String
    let subtitle: String
    let section: Section
    var id: URL { url }
}

/// Searches the same index Spotlight uses (NSMetadataQuery), as you type.
final class SearchEngine: ObservableObject {
    static let shared = SearchEngine()
    @Published private(set) var results: [SearchResult] = []

    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []
    private var pending: DispatchWorkItem?
    private var text = ""

    func search(_ raw: String) {
        pending?.cancel()
        stop()
        // '*' and '?' are wildcards in Spotlight queries; drop them from user input.
        let cleaned = raw.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "?", with: "")
        text = cleaned
        guard !cleaned.isEmpty else { results = []; return }

        results = [webResult(cleaned)] + results.filter { $0.section != .web }
        let work = DispatchWorkItem { [weak self] in self?.start(cleaned) }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work) // light debounce
    }

    private func start(_ text: String) {
        let q = NSMetadataQuery()
        q.predicate = NSPredicate(format: "%K LIKE[cd] %@", NSMetadataItemDisplayNameKey, "*\(text)*")
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

        for i in 0..<min(q.resultCount, 500) {
            guard let item = q.result(at: i) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  seen.insert(path).inserted else { continue }
            let type = item.value(forAttribute: "kMDItemContentType") as? String ?? ""
            let isApp = type == "com.apple.application-bundle"
            // Skip system/cache noise for files; apps can live anywhere.
            if !isApp && (path.contains("/Library/") || path.contains("/.")) { continue }

            let url = URL(fileURLWithPath: path)
            var name = item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String ?? url.lastPathComponent
            if name.hasSuffix(".app") { name = String(name.dropLast(4)) }
            let lower = name.lowercased()
            let rank = lower.hasPrefix(needle) ? 0
                : lower.split(separator: " ").contains { $0.hasPrefix(needle) } ? 1 : 2
            let used = item.value(forAttribute: "kMDItemLastUsedDate") as? Date ?? .distantPast
            let parent = (url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
            let result = SearchResult(url: url, name: name, subtitle: parent, section: isApp ? .apps : .files)
            if isApp { apps.append((result, rank, used)) } else { files.append((result, rank, used)) }
        }

        func best(_ list: [(SearchResult, Int, Date)], _ n: Int) -> [SearchResult] {
            list.sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.2 > $1.2 }.prefix(n).map(\.0)
        }
        results = best(apps, 6) + best(files, 10) + [webResult(text)]
        let state = PanelState.shared
        if state.selection >= results.count { state.selection = 0 }
    }

    private func webResult(_ text: String) -> SearchResult {
        var c = URLComponents(string: "https://www.google.com/search")!
        c.queryItems = [URLQueryItem(name: "q", value: text)]
        return SearchResult(url: c.url!, name: "Search the web for “\(text)”", subtitle: "Google", section: .web)
    }
}
