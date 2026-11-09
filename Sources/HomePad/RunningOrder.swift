import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The order of the tiles in the Running section, which you can change by dragging them around within it.
///
/// The section lists every running app, alphabetically until you move one. From then on the order is saved (as the apps'
/// paths) and the apps keep their places; an app that isn't in the saved order yet (just started, never placed) goes
/// last, alphabetically. A quit app's place is remembered, so when it starts again it comes back to where it was.
final class RunningOrder: ObservableObject {
    static let shared = RunningOrder()
    private let key: String

    /// Every app ever placed, in order: the running ones and the remembered places of the ones that aren't running.
    @Published private(set) var order: [String]

    init(key: String = "runningOrder") {
        self.key = key
        order = UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    /// The running apps in their order: placed ones first, in their saved order, then the rest alphabetically.
    func sorted(_ urls: [URL]) -> [URL] {
        let place = Dictionary(order.enumerated().map { ($1, $0) }) { first, _ in first }
        return urls.sorted { a, b in
            let pa = place[normalized(a).path], pb = place[normalized(b).path]
            switch (pa, pb) {
            case let (x?, y?): return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return IconCache.name(for: a).localizedCaseInsensitiveCompare(IconCache.name(for: b)) == .orderedAscending
            }
        }
    }

    /// The running apps' tiles, once per app, in this order (the Running section and the taskbar). Some apps run as
    /// more than one process (Firefox); two tiles with the same URL confused the grid.
    func shown(_ apps: [NSRunningApplication]) -> [URL] {
        var seen = Set<URL>()
        return sorted(apps.compactMap { $0.bundleURL.map(normalized) }.filter { seen.insert($0).inserted })
    }

    /// Puts what's on screen into the saved order (at the start of a drag), so only the dragged tile moves.
    func fix(_ shown: [URL]) {
        var full = order
        for url in shown where !full.contains(normalized(url).path) { full.append(normalized(url).path) }
        set(full)
    }

    /// `url` takes the place of `target`; the tiles between them move over by one.
    func move(_ url: URL, onto target: URL) {
        var full = order
        guard let from = full.firstIndex(of: normalized(url).path), let to = full.firstIndex(of: normalized(target).path),
              from != to else { return }
        let path = full.remove(at: from)
        full.insert(path, at: to)
        set(full)
    }

    /// Back to alphabetical: forgets every place.
    func sortAlphabetically() { set([]) }

    func set(_ new: [String]) {
        guard new != order else { return }
        order = new
        UserDefaults.standard.set(new, forKey: key)
    }
}

/// A Running tile that is being dragged. Only Running tiles accept it: it has a type of its own, visible to nothing
/// outside HomePad, so the categories, other apps and the desktop don't take it, and letting go anywhere else puts the
/// tile back where it was.
final class RunningDrag: ObservableObject {
    static let shared = RunningDrag()
    static let type = UTType(exportedAs: "local.mike.homepad.running-tile", conformingTo: .data)

    /// The tile in the air, drawn as an empty slot where it is.
    @Published private(set) var item: URL?
    private var before: [String] = []
    private(set) var cancelled = false
    private var dropped = false

    static func provider(for url: URL) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: type.identifier, visibility: .ownProcess) { done in
            done(Data(url.path.utf8), nil)
            return nil
        }
        return provider
    }

    func begin(_ url: URL, shown: [URL]) {
        RunningOrder.shared.fix(shown)
        before = RunningOrder.shared.order
        cancelled = false
        dropped = false
        item = url
    }

    /// Esc: the order goes back to what it was before the drag; what the drag still reports is ignored.
    func cancel() {
        guard item != nil, !cancelled else { return }
        cancelled = true
        withAnimation(.easeInOut(duration: 0.15)) { RunningOrder.shared.set(before) }
    }

    /// The tile was let go on a Running tile: the order as it is now stands.
    func landed() { dropped = true }

    /// The drag is over. Without a drop on a Running tile (let go elsewhere), the tile goes back.
    func end() {
        guard item != nil else { return }
        if !dropped { RunningOrder.shared.set(before) }
        item = nil
    }
}

/// Dropping on a Running tile: like the pinned tiles, the others make room when the pointer rests on one for a moment
/// (so crossing a tile's edge on the way elsewhere moves nothing), and the dragged one takes that place.
struct RunningDropDelegate: DropDelegate {
    let target: URL

    private func reorder() {
        guard let dragging = RunningDrag.shared.item, dragging != target else { return }
        withAnimation(.easeInOut(duration: 0.15)) { RunningOrder.shared.move(dragging, onto: target) }
    }

    func validateDrop(info: DropInfo) -> Bool { RunningDrag.shared.item != nil }

    func dropEntered(info: DropInfo) { PanelState.shared.noteDragActivity() }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        PanelState.shared.noteDragActivity()
        guard RunningDrag.shared.item != nil, !RunningDrag.shared.cancelled else { return DropProposal(operation: .move) }
        if EdgeHover.shared.settled(on: target) {
            reorder()
            EdgeHover.shared.noteReorder()
        }
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) { EdgeHover.shared.reset() }

    func performDrop(info: DropInfo) -> Bool {
        guard RunningDrag.shared.item != nil else { return false }
        if !RunningDrag.shared.cancelled {
            reorder()                       // let go before the tiles had moved
            RunningDrag.shared.landed()
        }
        PanelState.shared.endDrag()
        return true
    }
}

#if DEBUG
extension RunningOrder {
    /// `-HomePadRunningOrderTest`: checks the ordering on made-up apps, with a saved order of its own. Prints the result.
    static func selfTest() {
        let key = "runningOrderSelfTest"
        UserDefaults.standard.removeObject(forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }
        let o = RunningOrder(key: key)
        func app(_ name: String) -> URL { URL(fileURLWithPath: "/Applications/\(name).app") }
        let (a, b, c, d, e) = (app("A"), app("B"), app("C"), app("D"), app("E"))
        func names(_ urls: [URL]) -> String { urls.map { $0.deletingPathExtension().lastPathComponent }.joined() }
        var failures = 0
        func check(_ what: String, _ got: String, _ want: String) {
            if got != want { failures += 1 }
            print(got == want ? "ok  " : "FAIL", what, "->", got, got == want ? "" : "(wanted \(want))")
        }
        check("alphabetical until one is moved", names(o.sorted([d, b, a, c])), "ABCD")
        o.fix([a, b, c, d]); o.move(a, onto: c)
        check("A takes C's place", names(o.sorted([a, b, c, d])), "BCAD")
        o.move(d, onto: b)
        check("D takes B's place", names(o.sorted([a, b, c, d])), "DBCA")
        check("B quits: the others keep their order", names(o.sorted([a, c, d])), "DCA")
        check("B comes back to its place", names(o.sorted([a, b, c, d])), "DBCA")
        check("a new app goes last", names(o.sorted([e, a, b, c, d])), "DBCAE")
        o.fix([e, a, b, c, d]); o.move(e, onto: d)
        check("E to the front", names(o.sorted([a, b, c, d, e])), "EDBCA")
        o.move(c, onto: c)
        check("onto itself changes nothing", names(o.sorted([a, b, c, d, e])), "EDBCA")
        check("saved and read back", names(RunningOrder(key: key).sorted([a, b, c, d, e])), "EDBCA")
        let again = RunningOrder(key: key)
        again.sortAlphabetically()
        check("sort alphabetically", names(again.sorted([e, d, c, b, a])), "ABCDE")
        check("and that is saved too", names(RunningOrder(key: key).sorted([e, d, c, b, a])), "ABCDE")
        func keys(_ names: [String]) -> [String] { names.map { "/x/\($0).app" } }
        check("a category sorts by name, ignoring case", CategoryStore.alphabetical(keys(["c", "B2", "A", "b"])).map { String($0.dropFirst(3).dropLast(4)) }.joined(separator: ","), "A,b,B2,c")
        check("the same name keeps its order", CategoryStore.alphabetical(["/y/a.app", "/x/a.app", "/x/B.app"]).joined(separator: ","), "/y/a.app,/x/a.app,/x/B.app")
        print(failures == 0 ? "RUNNING ORDER: all ok" : "RUNNING ORDER: \(failures) failed")
    }
}
#endif
