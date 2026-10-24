import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Lets a click-and-drag on empty parts of the panel move the window.
struct WindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
    }
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// One of the round filter buttons beside the search field.
struct ScopeButton: View {
    let scope: SearchScope
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: scope.symbol)
                .font(.system(size: 20))
                .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                .frame(width: 58, height: 58)
                .background(Circle().fill(Color(nsColor: .textBackgroundColor)))
                .overlay(Circle().stroke(selected ? Color.accentColor : Color.primary.opacity(hovering ? 0.3 : 0.15),
                                         lineWidth: selected ? 1.5 : 0.5))
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("\(scope.title)  ⌘\((SearchScope.filters.firstIndex(of: scope) ?? 0) + 1)")
    }
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

            if state.query.isEmpty && state.scope == .all {
                HomeView()
            } else {
                SearchResultsView()
            }

            Divider().opacity(0.6)
            footer
        }
        .frame(width: panelSize.width, height: panelSize.height)
        .background(WindowDragArea())
        .onAppear { searchFocused = true }
        .onChange(of: state.focusToken) { _ in
            DispatchQueue.main.async { searchFocused = true }
        }
    }

    /// The search field (a tall white pill) with the four filters beside it, as in Spotlight.
    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField(state.scope.placeholder, text: $state.query)
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

            ForEach(SearchScope.filters, id: \.self) { scope in
                ScopeButton(scope: scope, selected: state.scope == scope) {
                    state.scope = state.scope == scope ? .all : scope
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
            Text(NSFullUserName()).font(.system(size: 13))
            Spacer()
            Button { AppDelegate.shared?.openSettings() } label: {
                Image(systemName: "gearshape").font(.system(size: 15))
            }
            .buttonStyle(.plain)
            .help("Settings")
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
    @AppStorage("columns") private var columns = 6
    @AppStorage("showRunning") private var showRunning = true

    private var grid: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: max(columns, 3))
    }

    private var unpinnedRunning: [URL] {
        running.apps.compactMap { $0.bundleURL.map(normalized) }.filter { !store.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Spacer()
                HoverLink(title: "Add App") { Launcher.chooseAppsToPin() }
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

                        if showRunning && !unpinnedRunning.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Running").font(.system(size: 14, weight: .semibold))
                                    Spacer()
                                    Label("Managed automatically", systemImage: "lock")
                                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                                }
                                LazyVGrid(columns: grid, spacing: 6) {
                                    ForEach(unpinnedRunning, id: \.self) { url in
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
                    .contextMenu {
                        Button("Add App…") { Launcher.chooseAppsToPin() }
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
                .contextMenu {
                    Button("Rename…") { Launcher.renameCategory(category) }
                    Button("Add App…") { Launcher.chooseAppsToPin(to: category.id) }
                    if category.id != store.essentialsID {
                        Divider()
                        Button("Delete Category") { store.delete(category.id) }
                    }
                }

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
            Button("Show in Finder") { Launcher.reveal(url) }
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
        if categories.count > 1 {
            Menu("Pin App") {
                ForEach(categories) { c in Button(c.name) { CategoryStore.shared.add(url, to: c.id) } }
            }
        } else {
            Button("Pin App") { CategoryStore.shared.add(url) }
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
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if items.isEmpty && state.scope != .all {
                        Text(state.scope.emptyMessage)
                            .font(.callout).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 40)
                    }
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
                                    if let name = result.actionName {
                                        Launcher.runShortcut(name)
                                    } else if let answer = result.copyText {
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
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }
            .onChange(of: state.selection) { i in
                if items.indices.contains(i) { proxy.scrollTo(items[i].id) }
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
            if let symbol = result.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
            } else {
                Image(nsImage: IconCache.icon(for: result.url))
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(result.name).font(.system(size: 13)).lineLimit(1)
                Text(result.subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            if selected {
                Text(result.actionName != nil ? "↩ run" : result.copyText != nil ? "↩ copy"
                     : result.url.isFileURL ? "↩ open   ⌘↩ show" : "↩ search")
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
                    Button("Unpin App") { CategoryStore.shared.remove(result.url) }
                } else {
                    PinMenu(url: result.url)
                }
            }
        }
    }
}
