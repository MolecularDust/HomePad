import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Lets a click-and-drag on empty parts of the panel move the window.
struct WindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        /// A press on empty panel takes focus out of the search field, then (if it turns into a drag) moves the window.
        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(nil)
            window?.performDrag(with: event)
        }
    }
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// An icon button in the panel's footer that shows its name in a small label at once when the pointer is over it
/// (the system's tooltip waits a second or more, and is easy to miss).
struct FooterIcon: View {
    let symbol: String
    let name: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(hovering ? Color.primary : Color.secondary)
        .onHover { hovering = $0 }
        .accessibilityLabel(name)
        .overlay(alignment: .topTrailing) {
            if hovering {
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.regularMaterial))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
                    .fixedSize()
                    .offset(y: -30)
                    .allowsHitTesting(false)
            }
        }
        .zIndex(1)
    }
}

/// Your picture and name in the footer. Clicking opens System Settings on the Apple Account page.
struct FooterProfile: View {
    @State private var hovering = false

    var body: some View {
        Button {
            PanelController.shared.hide(restoreFocus: false)
            if let url = URL(string: "x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings") {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                Text(NSFullUserName()).font(.system(size: 13))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 8).fill(hovering ? Color.primary.opacity(0.08) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel("Apple Account")
        .overlay(alignment: .topLeading) {
            if hovering {
                Text("Apple Account")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.regularMaterial))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
                    .fixedSize()
                    .offset(y: -34)
                    .allowsHitTesting(false)
            }
        }
        .zIndex(1)
    }
}

/// Moves the panel when an empty part of it is dragged. The window's own drag-by-background doesn't reach the
/// areas SwiftUI draws (the lists, the footer), so this does it by hand. Tiles and buttons have their own gestures,
/// which take precedence.
private final class MoveDrag { var active = false; var mouse = NSPoint.zero; var origin = NSPoint.zero }

struct MovesWindowWhenDragged: ViewModifier {
    @State private var drag = MoveDrag()

    func body(content: Content) -> some View {
        content.gesture(DragGesture(minimumDistance: 4)
            .onChanged { _ in
                let panel = PanelController.shared
                if !drag.active { drag.active = true; drag.mouse = NSEvent.mouseLocation; drag.origin = panel.frame.origin }
                let mouse = NSEvent.mouseLocation
                panel.move(to: NSPoint(x: drag.origin.x + mouse.x - drag.mouse.x, y: drag.origin.y + mouse.y - drag.mouse.y))
            }
            .onEnded { _ in drag.active = false })
    }
}

extension View {
    func movesWindowWhenDragged() -> some View { modifier(MovesWindowWhenDragged()) }
}

struct SpotlightPlusView: View {
    @ObservedObject private var state = PanelState.shared
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 14)

            if state.query.isEmpty {
                HomeView()
            } else {
                SearchResultsView()
            }

            Divider().opacity(0.6)
            footer
        }
        .frame(minWidth: 520, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
        .background(WindowDragArea())
        // A click or drag on empty space takes focus out of the search field and (for a drag) moves the window.
        .contentShape(Rectangle())
        .onTapGesture { searchFocused = false }
        .movesWindowWhenDragged()
        .onAppear { searchFocused = true }
        .onChange(of: state.focusToken) { _ in
            searchFocused = false
            DispatchQueue.main.async { searchFocused = true }
        }
    }

    /// The search field: a tall white pill.
    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                if !state.query.isEmpty {
                    // Back to the pinned apps (Esc does the same, a step at a time).
                    Button { state.goHome() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Back to your apps  Esc")
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                TextField("Search apps, documents and files", text: $state.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .focused($searchFocused)
                if !state.query.isEmpty {
                    Button { state.query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 58)
            .background(Capsule().fill(Color(nsColor: .textBackgroundColor)))
            .overlay(Capsule().stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)

        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            FooterProfile()
            Spacer()
            FooterIcon(symbol: "arrow.counterclockwise", name: "Reset window") { PanelController.shared.resetFrame() }
            FooterIcon(symbol: "gearshape", name: "Settings") { AppDelegate.shared?.openSettings() }
        }
        .padding(.horizontal, 24)
        .frame(height: 52)
        .background(Color.primary.opacity(0.03))
    }
}

/// Plain "+ Title" text that turns green under the pointer.
struct HoverLink: View {
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "plus")
                .font(.system(size: 12))
                .foregroundStyle(hovering ? Color.green : Color.secondary)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - Categories + running apps

struct HomeView: View {
    @ObservedObject private var store = CategoryStore.shared
    @ObservedObject private var running = RunningApps.shared
    @AppStorage("columns") private var columns = 8
    @AppStorage("showRunning") private var showRunning = true

    private var grid: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: max(columns, 3))
    }

    /// Every running app, like the Dock's running indicators, pinned or not.
    private var runningApps: [URL] {
        running.apps.compactMap { $0.bundleURL.map(normalized) }
            .sorted { IconCache.name(for: $0).localizedCaseInsensitiveCompare(IconCache.name(for: $1)) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Spacer()
                HoverLink(title: "Add App") { Launcher.chooseAppsToPin() }
                HoverLink(title: "Add File or Folder") { Launcher.chooseFilesToPin() }
                HoverLink(title: "Add Category") { Launcher.addCategory() }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 4)

            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(store.categories) { category in
                            CategorySection(category: category, grid: grid, running: running)
                        }

                        if showRunning && !runningApps.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Running").font(.system(size: 14, weight: .semibold))
                                    Spacer()
                                    Label("Managed automatically", systemImage: "lock")
                                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                                }
                                LazyVGrid(columns: grid, spacing: 6) {
                                    ForEach(runningApps, id: \.self) { url in
                                        AppTile(url: url, isRunning: true, categoryID: nil)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    // Fill the whole scroll area so a right-click on empty space lands here.
                    .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .topLeading)
                    .contentShape(Rectangle())
                    .movesWindowWhenDragged()          // inside the scroll view, which takes its own mouse events
                    .contextMenu {
                        // Outside every category (below the last one, in the Running section): into Essentials.
                        Button("Add App to \(store.categories[0].name)…") { Launcher.chooseAppsToPin() }
                        Button("Add File or Folder to \(store.categories[0].name)…") { Launcher.chooseFilesToPin() }
                        Divider()
                        Button("Add Category…") { Launcher.addCategory() }
                    }
                }
            }
        }
    }
}

struct CategorySection: View {
    let category: Category
    let grid: [GridItem]
    @ObservedObject var running: RunningApps
    @ObservedObject private var store = CategoryStore.shared

    var body: some View {
        let urls = store.urls(in: category.id)
        VStack(alignment: .leading, spacing: 6) {
            Text(category.name).font(.system(size: 14, weight: .semibold))

            LazyVGrid(columns: grid, spacing: 6) {
                ForEach(urls, id: \.self) { url in
                    AppTile(url: url, isRunning: running.isRunning(url), categoryID: category.id)
                        .onDrag {
                            PanelState.shared.draggingItem = url
                            return NSItemProvider(object: url.path as NSString)
                        }
                        .onDrop(of: [.plainText, .fileURL], delegate: TileDropDelegate(target: url))
                }
                if urls.isEmpty {
                    PlaceholderTile(categoryID: category.id)
                }
            }
            // Drop a tile or Finder items onto the category's empty space to append them.
            .onDrop(of: [.plainText, .fileURL], delegate: CategoryDropDelegate(category: category.id))
        }
        // A right-click anywhere in this category's band that isn't on a tile (its title, the gaps between and
        // after the tiles) adds to this category. A tile has its own menu, which takes precedence.
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .movesWindowWhenDragged()                // the band claims the mouse for its menu, so it moves the window itself
        .contextMenu {
            Button("Add App to \(category.name)…") { Launcher.chooseAppsToPin(to: category.id) }
            Button("Add File or Folder to \(category.name)…") { Launcher.chooseFilesToPin(to: category.id) }
            Divider()
            Button("Add Category…") { Launcher.addCategory() }
            Button("Rename \(category.name)…") { Launcher.renameCategory(category) }
            if category.id != store.essentialsID {
                Button("Delete \(category.name)") { store.delete(category.id) }
            }
        }
    }
}

private struct TileFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

/// categoryID is nil for tiles in the Running section, which can't be edited.
struct AppTile: View {
    let url: URL
    let isRunning: Bool
    let categoryID: UUID?
    @State private var hovering = false
    @State private var frame = CGRect.zero

    var body: some View {
        VStack(spacing: 5) {
            Image(nsImage: IconCache.icon(for: url))
                .resizable()
                .interpolation(.high)
                .frame(width: 52, height: 52)
            Text(IconCache.name(for: url))
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 4)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(isRunning ? Color.red : Color.clear)
                .frame(width: 18, height: 3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(hovering ? Color.primary.opacity(0.09) : .clear))
        .background(GeometryReader { Color.clear.preference(key: TileFrameKey.self, value: $0.frame(in: .global)) })
        .onPreferenceChange(TileFrameKey.self) { frame = $0 }
        .contentShape(Rectangle())
        .onHover { inside in
            hovering = inside
            if isRunning {
                WindowPreviewController.shared.hover(app: RunningApps.shared.app(for: url), over: inside, tile: frame)
            }
        }
        .onTapGesture { Launcher.open(url) }
        .help(IconCache.name(for: url))
        .contextMenu {
            Button("Open") { Launcher.open(url) }
            if url.path != trashURL.path { Button("Show in Finder") { Launcher.reveal(url) } }
            Divider()
            if let categoryID {
                Button("Move Left") { CategoryStore.shared.shift(url, by: -1) }
                Button("Move Right") { CategoryStore.shared.shift(url, by: 1) }
                let others = CategoryStore.shared.categories.filter { $0.id != categoryID }
                if !others.isEmpty {
                    Menu("Move to") {
                        ForEach(others) { c in Button(c.name) { CategoryStore.shared.move(url, toCategory: c.id) } }
                    }
                }
                Button(url.pathExtension == "app" ? "Unpin App" : "Unpin") { CategoryStore.shared.remove(url) }
            } else if CategoryStore.shared.contains(url) {
                Button("Unpin App") { CategoryStore.shared.remove(url) }
            } else {
                PinMenu(url: url)
            }
            if isRunning {
                Divider()
                if let app = RunningApps.shared.app(for: url), WindowCatalog.closableWindowCount(for: app.processIdentifier) > 0 {
                    Button("Close Windows") { Launcher.closeWindows(url) }
                }
                Button("Close App") { Launcher.quit(url) }
            }
        }
    }
}

/// "Pin App" — straight to Essentials when it's the only category, otherwise a choice of category.
struct PinMenu: View {
    let url: URL
    var body: some View {
        let categories = CategoryStore.shared.categories
        let title = url.pathExtension == "app" ? "Pin App" : "Pin"
        if categories.count > 1 {
            Menu(title) {
                ForEach(categories) { c in Button(c.name) { CategoryStore.shared.add(url, to: c.id) } }
            }
        } else {
            Button(title) { CategoryStore.shared.add(url) }
        }
    }
}

/// Grayed-out stand-in shown in a category that has no apps yet.
struct PlaceholderTile: View {
    let categoryID: UUID

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(.quaternary)
                Image(systemName: "plus").font(.system(size: 18)).foregroundStyle(.tertiary)
            }
            .frame(width: 52, height: 52)
            Text("Add your app here")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .padding(.horizontal, 4)
            Color.clear.frame(width: 18, height: 3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { Launcher.chooseAppsToPin(to: categoryID) }
    }
}

/// Drag a tile over another to reorder (or move it into that tile's category); drop a Finder item on a tile to insert it there.
struct TileDropDelegate: DropDelegate {
    let target: URL

    func dropEntered(info: DropInfo) {
        let store = CategoryStore.shared
        guard let dragging = PanelState.shared.draggingItem, dragging != target,
              let to = store.location(of: target) else { return }
        withAnimation(.easeInOut(duration: 0.15)) { store.move(dragging, toCategory: to.category, at: to.index) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        if PanelState.shared.draggingItem != nil {
            PanelState.shared.draggingItem = nil
            return true
        }
        let providers = info.itemProviders(for: [.fileURL])
        let location = CategoryStore.shared.location(of: target)
        FileDrop.load(providers) { urls in
            for (offset, url) in urls.enumerated() {
                CategoryStore.shared.add(url, to: location?.category, at: location.map { $0.index + offset })
            }
        }
        return !providers.isEmpty
    }
}

struct CategoryDropDelegate: DropDelegate {
    let category: UUID

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        if let dragging = PanelState.shared.draggingItem {
            CategoryStore.shared.move(dragging, toCategory: category)
            PanelState.shared.draggingItem = nil
            return true
        }
        let providers = info.itemProviders(for: [.fileURL])
        FileDrop.load(providers) { $0.forEach { CategoryStore.shared.add($0, to: category) } }
        return !providers.isEmpty
    }
}

// MARK: - Search results

struct SearchResultsView: View {
    @ObservedObject private var search = SearchEngine.shared
    @ObservedObject private var state = PanelState.shared

    var body: some View {
        let items = search.results
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, result in
                            VStack(alignment: .leading, spacing: 2) {
                                if result.section != .calculator && (index == 0 || items[index - 1].section != result.section) {
                                    Text(result.section.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.top, index == 0 ? 0 : 10)
                                        .padding(.leading, 10)
                                        .padding(.bottom, 2)
                                }
                                Group {
                                    if result.section == .calculator {
                                        CalculatorRow(result: result, selected: index == state.selection)
                                    } else {
                                        ResultRow(result: result, selected: index == state.selection)
                                    }
                                }
                                .onTapGesture {
                                    if let answer = result.copyText {
                                        Launcher.copy(answer)
                                        PanelController.shared.hide(restoreFocus: true)
                                    } else {
                                        Launcher.open(result.url)
                                    }
                                }
                                .onHover { if $0 { state.selection = index } }
                            }
                            .id(result.id)
                        }
                        FullDiskAccessHint().padding(.top, 8)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
                    // Fill the area, so a click on the empty space goes back to the pinned apps.
                    .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .topLeading)
                    .contentShape(Rectangle())
                    .onTapGesture { state.goHome() }
                    .movesWindowWhenDragged()
                }
                .onChange(of: state.selection) { i in
                    if items.indices.contains(i) { proxy.scrollTo(items[i].id) }
                }
            }
        }
    }
}

/// Without Full Disk Access macOS keeps Documents, Desktop and Downloads out of the search results, which
/// looks like files that don't exist. This says so, and takes you to the switch.
struct FullDiskAccessHint: View {
    @AppStorage("hideFullDiskHint") private var hidden = false
    @State private var granted = Permissions.fullDiskAccess

    var body: some View {
        if !granted && !hidden {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield").font(.system(size: 18)).foregroundStyle(.secondary).frame(width: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Files in Documents, Desktop and Downloads aren't searched yet")
                        .font(.system(size: 12, weight: .medium))
                    Text("Click to allow Full Disk Access, then relaunch SpotlightPlus")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { hidden = true } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                        .frame(width: 22, height: 22).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Don't show this again")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
            .contentShape(Rectangle())
            .onTapGesture {
                Permissions.openSettings("Privacy_AllFiles")
                PanelController.shared.hide(restoreFocus: false)
            }
        }
    }
}

/// A calculator answer: the sum in small type, the result large, and a button that copies it.
struct CalculatorRow: View {
    let result: SearchResult
    let selected: Bool
    @State private var copied = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.subtitle).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                Text(result.name).font(.system(size: 30, weight: .medium)).lineLimit(1).minimumScaleFactor(0.5)
            }
            Spacer()
            if selected {
                Text("↩ copy").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Button {
                Launcher.copy(result.copyText ?? result.name)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 14))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.primary.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .help("Copy the answer")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(selected ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1)))
        .contentShape(Rectangle())
    }
}

struct ResultRow: View {
    let result: SearchResult
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: IconCache.icon(for: result.url))
                .resizable()
                .frame(width: 30, height: 30)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(result.name).font(.system(size: 13)).lineLimit(1)
                Text(result.subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            if selected {
                Text(result.url.isFileURL ? "↩ open   ⌘↩ show" : "↩ search")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(selected ? Color.accentColor.opacity(0.22) : .clear))
        .contentShape(Rectangle())
        .contextMenu {
            if result.url.isFileURL {
                Button("Open") { Launcher.open(result.url) }
                Button("Show in Finder") { Launcher.reveal(result.url) }
                Divider()
                if CategoryStore.shared.contains(result.url) {
                    Button(result.url.pathExtension == "app" ? "Unpin App" : "Unpin") { CategoryStore.shared.remove(result.url) }
                } else {
                    PinMenu(url: result.url)
                }
            }
        }
    }
}
