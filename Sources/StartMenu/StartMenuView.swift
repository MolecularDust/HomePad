import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct StartMenuView: View {
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
        .frame(width: panelSize.width, height: panelSize.height)
        .onAppear { searchFocused = true }
        .onChange(of: state.focusToken) { _ in
            DispatchQueue.main.async { searchFocused = true }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search apps, documents and files", text: $state.query)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .focused($searchFocused)
            if !state.query.isEmpty {
                Button { state.query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08)))
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

// MARK: - Pinned grid + running apps

struct HomeView: View {
    @ObservedObject private var store = PinnedStore.shared
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
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Pinned").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Button { Launcher.chooseAppsToPin() } label: {
                        Label("Add App", systemImage: "plus").font(.system(size: 12))
                    }
                    .buttonStyle(.borderless)
                }

                LazyVGrid(columns: grid, spacing: 6) {
                    ForEach(store.items, id: \.self) { url in
                        AppTile(url: url, isRunning: running.isRunning(url), pinned: true)
                            .onDrag {
                                PanelState.shared.draggingItem = url
                                return NSItemProvider(object: url.path as NSString)
                            }
                            .onDrop(of: [.plainText, .fileURL], delegate: TileDropDelegate(target: url))
                    }
                }
                // Drop apps from Finder onto empty space to append them.
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    FileDrop.load(providers) { $0.forEach { PinnedStore.shared.add($0) } }
                    return true
                }

                if store.items.isEmpty {
                    Text("Nothing pinned yet. Click Add App, drag apps here from Finder, or right-click a search result.")
                        .font(.callout).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 30)
                }

                if showRunning && !unpinnedRunning.isEmpty {
                    Text("Running").font(.system(size: 14, weight: .semibold)).padding(.top, 12)
                    LazyVGrid(columns: grid, spacing: 6) {
                        ForEach(unpinnedRunning, id: \.self) { url in
                            AppTile(url: url, isRunning: true, pinned: false)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
}

struct AppTile: View {
    let url: URL
    let isRunning: Bool
    let pinned: Bool
    @State private var hovering = false

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
            Circle()
                .fill(isRunning ? Color.primary.opacity(0.65) : Color.clear)
                .frame(width: 4, height: 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(hovering ? Color.primary.opacity(0.09) : .clear))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { Launcher.open(url) }
        .help(IconCache.name(for: url))
        .contextMenu {
            Button("Open") { Launcher.open(url) }
            Button("Show in Finder") { Launcher.reveal(url) }
            Divider()
            if pinned {
                Button("Move Left") { PinnedStore.shared.shift(url, by: -1) }
                Button("Move Right") { PinnedStore.shared.shift(url, by: 1) }
                Button("Unpin from Start") { PinnedStore.shared.remove(url) }
            } else {
                Button("Pin to Start") { PinnedStore.shared.add(url) }
            }
            if isRunning {
                Divider()
                Button("Quit") { Launcher.quit(url) }
            }
        }
    }
}

/// Drag a tile over another to reorder; drop a Finder item on a tile to insert it there.
struct TileDropDelegate: DropDelegate {
    let target: URL

    func dropEntered(info: DropInfo) {
        let store = PinnedStore.shared
        guard let dragging = PanelState.shared.draggingItem, dragging != target,
              let to = store.items.firstIndex(of: target) else { return }
        withAnimation(.easeInOut(duration: 0.15)) { store.move(dragging, to: to) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        if PanelState.shared.draggingItem != nil {
            PanelState.shared.draggingItem = nil
            return true
        }
        let providers = info.itemProviders(for: [.fileURL])
        let index = PinnedStore.shared.items.firstIndex(of: target)
        FileDrop.load(providers) { urls in
            for (offset, url) in urls.enumerated() {
                PinnedStore.shared.add(url, at: index.map { $0 + offset })
            }
        }
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
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, result in
                        VStack(alignment: .leading, spacing: 2) {
                            if index == 0 || items[index - 1].section != result.section {
                                Text(result.section.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, index == 0 ? 0 : 10)
                                    .padding(.leading, 10)
                                    .padding(.bottom, 2)
                            }
                            ResultRow(result: result, selected: index == state.selection)
                                .onTapGesture { Launcher.open(result.url) }
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
                if PinnedStore.shared.contains(result.url) {
                    Button("Unpin from Start") { PinnedStore.shared.remove(result.url) }
                } else {
                    Button("Pin to Start") { PinnedStore.shared.add(result.url) }
                }
            }
        }
    }
}
