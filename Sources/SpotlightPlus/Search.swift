import AppKit

struct SearchResult: Identifiable, Hashable {
    enum Section: Int { case calculator, apps, files, web
        var title: String {
            switch self {
            case .calculator: return "Calculator"
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
    /// Set on a calculator answer: what Return or the copy button puts on the clipboard.
    var copyText: String?
    var id: URL { url }
}

/// Searches the same index Spotlight uses (NSMetadataQuery), as you type.
///
/// Kept fast in three ways, measured on a full index: names are matched at the start of a word, as Spotlight does
/// (matching anywhere inside a name made a one-letter search run for many seconds over a quarter of a million files);
/// Spotlight sorts the matches by when they were last used, so only the first few are read (reading an item's details
/// costs about 0.2 ms per attribute, and reading 500 took 340 ms); and the queries run and are read on a queue of their
/// own, so typing never waits for them.
final class SearchEngine: ObservableObject {
    static let shared = SearchEngine()
    @Published private(set) var results: [SearchResult] = []

    private static let appsShown = 6, filesShown = 10
    /// How many matches are read at most to find them (files in Library folders and hidden ones are skipped).
    private static let appsRead = 30, filesRead = 200
    private static let noise = ["/Library/", "/.", "/node_modules/"]

    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()
    // Only touched on `queue`.
    private var queries: [NSMetadataQuery] = []
    private var observers: [NSObjectProtocol] = []

    private var pending: DispatchWorkItem?
    private var generation = 0          // answers for an older text are dropped
    private var typed = ""

    func search(_ raw: String) {
        pending?.cancel()
        generation += 1
        stopQueries()
        // '*' and '?' are wildcards in Spotlight queries; drop them from user input.
        let cleaned = raw.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "?", with: "")
        typed = raw
        guard !cleaned.isEmpty else { results = []; return }

        // The web search gets what was typed (the wildcard stripping is only for the Spotlight index query).
        let webText = raw.trimmingCharacters(in: .whitespaces)
        let calculation = calculatorResults()
        if !calculation.isEmpty {
            results = calculation + [webResult(webText)]      // a sum isn't a file search
            return
        }
        results = [webResult(webText)] + results.filter { $0.section == .apps || $0.section == .files }
        let mine = generation
        let work = DispatchWorkItem { [weak self] in self?.start(cleaned, generation: mine) }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work) // light debounce
    }

    private func start(_ text: String, generation: Int) {
        let escaped = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        // Every word of the name is tried: "safari", "screen shot" and "my screen" all match "scr".
        let name = "kMDItemDisplayName == \"\(escaped)*\"cdw"
        let app = "kMDItemContentType == \"com.apple.application-bundle\""
        queue.addOperation { [weak self] in
            guard let self else { return }
            self.stopQueriesOnQueue()
            let apps = self.makeQuery("(\(name)) && \(app)", scopes: [NSMetadataQueryLocalComputerScope])
            // Your files: the home folder and any other drives. The rest of the startup disk holds system files
            // (/usr/share, /System ...) that only crowded out real matches. (One scope per home folder instead was
            // much slower to gather: over a second and a half.)
            let files = self.makeQuery("(\(name)) && !(\(app))", scopes: Self.fileScopes())
            self.queries = [apps, files]
            let nc = NotificationCenter.default
            for query in self.queries {
                for note in [Notification.Name.NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate] {
                    self.observers.append(nc.addObserver(forName: note, object: query, queue: self.queue) { [weak self] _ in
                        self?.collect(text, apps: apps, files: files, generation: generation)
                    })
                }
                query.start()
            }
        }
    }

    private func makeQuery(_ format: String, scopes: [Any]) -> NSMetadataQuery {
        let query = NSMetadataQuery()
        query.operationQueue = queue
        query.predicate = NSPredicate(fromMetadataQueryString: format)
        query.searchScopes = scopes
        query.sortDescriptors = [NSSortDescriptor(key: "kMDItemLastUsedDate", ascending: false)]
        return query
    }

    private static func fileScopes() -> [Any] {
        let drives = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: [.skipHiddenVolumes])?
            .filter { $0.path != "/" } ?? []
        return [NSMetadataQueryUserHomeScope] + drives
    }

    private func stopQueries() {
        queue.addOperation { [weak self] in self?.stopQueriesOnQueue() }
    }

    private func stopQueriesOnQueue() {
        queries.forEach { $0.stop() }
        queries = []
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
    }

    /// Runs on `queue`. Reads the most recently used matches of each kind, best names first.
    private func collect(_ text: String, apps: NSMetadataQuery, files: NSMetadataQuery, generation: Int) {
        let needle = text.lowercased()
        func read(_ query: NSMetadataQuery, section: SearchResult.Section, limit: Int, shown: Int) -> [SearchResult] {
            query.disableUpdates()
            defer { query.enableUpdates() }
            var found: [(result: SearchResult, rank: Int, order: Int)] = []
            var seen = Set<String>()
            for i in 0..<min(query.resultCount, limit) {
                guard let item = query.result(at: i) as? NSMetadataItem,
                      let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                      seen.insert(path).inserted else { continue }
                // Skip app support, hidden items and code packages for files; apps can live anywhere.
                if section == .files && Self.noise.contains(where: path.contains) { continue }
                let url = URL(fileURLWithPath: path)
                var name = item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String ?? url.lastPathComponent
                if name.hasSuffix(".app") { name = String(name.dropLast(4)) }
                // Names that start with what was typed come before ones where a later word does.
                let rank = name.lowercased().hasPrefix(needle) ? 0 : 1
                let parent = (url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
                found.append((SearchResult(url: url, name: name, subtitle: parent, section: section), rank, i))
            }
            return found.sorted { ($0.rank, $0.order) < ($1.rank, $1.order) }.prefix(shown).map(\.result)
        }
        let list = read(apps, section: .apps, limit: Self.appsRead, shown: Self.appsShown)
            + read(files, section: .files, limit: Self.filesRead, shown: Self.filesShown)
        DispatchQueue.main.async { [weak self] in
            guard let self, generation == self.generation else { return }
            self.results = list + [self.webResult(self.typed.trimmingCharacters(in: .whitespaces))]
            let state = PanelState.shared
            if state.selection >= self.results.count { state.selection = 0 }
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
