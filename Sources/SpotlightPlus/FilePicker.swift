import AppKit
import SwiftUI

let trashURL = URL(fileURLWithPath: NSHomeDirectory() + "/.Trash")

/// "Add File or Folder": a file browser in our own window, styled like Add Apps. The system open dialog can't have
/// a title bar, and never shows the Trash (a hidden folder), which this window offers as an entry of its own.
enum FilePicker {
    static func show(for category: UUID?) {
        let store = CategoryStore.shared
        let target = category ?? store.essentialsID
        let name = store.categories.first { $0.id == target }?.name ?? "Essentials"
        let modal = ModalWindow(title: "Add Files and Folders to \(name)") { modal in
            FilePickerView(category: target, close: modal.close)
        }
        modal.show()
    }
}

private enum Place: Hashable {
    case folder(URL)
    case trash
}

private struct Entry: Identifiable {
    let url: URL
    /// A folder you can open (packages such as apps are treated as files).
    let isFolder: Bool
    var id: URL { url }
}

private struct SidebarItem: Identifiable {
    let title: String
    let symbol: String
    let place: Place
    var id: String { title }
}

/// A place in the sidebar. Clicking opens it; the round button on its right picks the place itself for adding.
private struct SidebarRow: View {
    let item: SidebarItem
    let current: Bool
    let added: Bool
    let picked: Bool
    let go: () -> Void
    let toggle: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.symbol).frame(width: 18).foregroundStyle(Color.accentColor)
            Text(item.title).font(.system(size: 13)).lineLimit(1)
            Spacer()
            // Always laid out, only hidden: showing it on hover must not change the row's height.
            let visible = hovering || picked || added
            Button(action: toggle) {
                Image(systemName: added ? "checkmark.circle" : (picked ? "checkmark.circle.fill" : "plus.circle"))
                    .font(.system(size: 15))
                    .foregroundStyle(picked ? Color.accentColor : Color.secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .help(added ? "\(item.title) is already added" : "Add \(item.title) itself")
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(RoundedRectangle(cornerRadius: 6).fill(current ? Color.accentColor.opacity(0.22) : .clear))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: go)
    }
}

private struct FilePickerView: View {
    let category: UUID
    let close: () -> Void
    @ObservedObject private var store = CategoryStore.shared
    @State private var place = Place.folder(FileManager.default.homeDirectoryForCurrentUser)
    @State private var history: [Place] = []
    @State private var query = ""
    @State private var selected = Set<URL>()
    @State private var pickedPlace: URL?
    @State private var showHidden = false
    @State private var entries: [Entry] = []
    @State private var unreadable = false
    @FocusState private var searchFocused: Bool

    private let home = FileManager.default.homeDirectoryForCurrentUser

    private var places: [SidebarItem] {
        func item(_ title: String, _ symbol: String, _ path: String) -> SidebarItem {
            SidebarItem(title: title, symbol: symbol, place: .folder(URL(fileURLWithPath: path)))
        }
        return [
            SidebarItem(title: "Home", symbol: "house", place: .folder(home)),
            item("Desktop", "menubar.dock.rectangle", home.path + "/Desktop"),
            item("Documents", "doc", home.path + "/Documents"),
            item("Downloads", "arrow.down.circle", home.path + "/Downloads"),
            item("Pictures", "photo", home.path + "/Pictures"),
            item("Movies", "film", home.path + "/Movies"),
            item("Music", "music.note", home.path + "/Music"),
            item("Applications", "square.grid.2x2", "/Applications"),
            SidebarItem(title: "Trash", symbol: "trash", place: .trash),
        ]
    }

    private var volumes: [SidebarItem] {
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeNameKey],
                                                         options: [.skipHiddenVolumes]) ?? []
        return urls.map { url in
            let name = (try? url.resourceValues(forKeys: [.volumeNameKey]).volumeName) ?? url.lastPathComponent
            return SidebarItem(title: name, symbol: "externaldrive", place: .folder(url))
        }
    }

    private var currentFolder: URL? {
        if case .folder(let url) = place { return url }
        return nil
    }

    private var placeTitle: String {
        switch place {
        case .trash: return "Trash"
        case .folder(let url): return url.path == "/" ? "Macintosh HD" : IconCache.name(for: url)
        }
    }

    private var shown: [Entry] {
        query.isEmpty ? entries : entries.filter { $0.url.lastPathComponent.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                Text((currentFolder.map { ($0.path as NSString).abbreviatingWithTildeInPath }) ?? "~/.Trash")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24).padding(.bottom, 6)
                content
                Divider().opacity(0.6)
                footer
            }
        }
        .frame(width: panelSize.width, height: panelSize.height)
        .onAppear { reload(); DispatchQueue.main.async { searchFocused = true } }
        .onChange(of: place) { _ in query = ""; reload() }
        .onChange(of: showHidden) { _ in reload() }
    }

    // MARK: Pieces

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                sidebarSection("Places", places)
                if !volumes.isEmpty { sidebarSection("Locations", volumes).padding(.top, 10) }
            }
            .padding(10)
        }
        .frame(width: 180)
        .background(Color.primary.opacity(0.03))
    }

    private func sidebarSection(_ title: String, _ items: [SidebarItem]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).padding(.leading, 8).padding(.bottom, 2)
            ForEach(items) { item in
                let url = url(of: item.place)
                SidebarRow(item: item, current: place == item.place,
                           added: store.contains(url), picked: selected.contains(url),
                           go: { choose(item.place) }, toggle: { toggle(url) })
                    .onDrag { NSItemProvider(object: url as NSURL) }
            }
        }
    }

    /// What a place stands for when it is added itself (Documents, Downloads, the Trash ...).
    private func url(of place: Place) -> URL {
        switch place {
        case .folder(let url): return url
        case .trash: return trashURL
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { back() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color(nsColor: .textBackgroundColor)))
                    .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
                    .opacity(history.isEmpty ? 0.4 : 1)
            }
            .buttonStyle(.plain)
            .help("Back")

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 15, weight: .medium)).foregroundStyle(.secondary)
                TextField("Search in \(placeTitle)", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($searchFocused)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(Capsule().fill(Color(nsColor: .textBackgroundColor)))
            .overlay(Capsule().stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
        }
    }

    @ViewBuilder private var content: some View {
        if place == .trash {
            trashPage
        } else if unreadable {
            VStack(spacing: 8) {
                Image(systemName: "lock").font(.system(size: 26)).foregroundStyle(.secondary)
                Text("SpotlightPlus can't look inside this folder.").font(.system(size: 13, weight: .medium))
                Text("Allow access if macOS asks, or turn on Full Disk Access in Settings. You can still add the folder itself.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if shown.isEmpty {
            Text(query.isEmpty ? "This folder is empty." : "Nothing matches “\(query)”.")
                .font(.callout).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(shown) { entry in
                        FileTile(url: entry.url, isFolder: entry.isFolder, added: store.contains(entry.url),
                                 selected: selected.contains(entry.url),
                                 toggle: { toggle(entry.url) },
                                 open: { openEntry(entry) })
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
    }

    /// The Trash can't be browsed like a folder here: it is one item to pin.
    private var trashPage: some View {
        let added = store.contains(trashURL)
        let picked = selected.contains(trashURL)
        return VStack(spacing: 8) {
            FileTile(url: trashURL, isFolder: false, added: added, selected: picked,
                     toggle: { toggle(trashURL) },
                     open: { add([trashURL]) })
                .frame(width: 150)
            Text("Pins your Trash. Clicking the tile opens it in Finder.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            if added { Text("Already added.").font(.system(size: 11)).foregroundStyle(.tertiary) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Toggle("Show hidden items", isOn: $showHidden).toggleStyle(.checkbox).font(.system(size: 12))
            Spacer()
            if let folder = currentFolder, !store.contains(folder) {
                Button("Add This Folder") { add([folder]) }
            }
            Button("Cancel", action: close).keyboardShortcut(.cancelAction)
            Button(selected.isEmpty ? "Add" : "Add \(selected.count)") { add(Array(selected)) }
                .keyboardShortcut(.defaultAction)
                .disabled(selected.isEmpty)
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
        .background(Color.primary.opacity(0.03))
    }

    // MARK: Actions

    /// A click on a place in the sidebar opens it and picks it itself, so Add is ready (only one place at a time;
    /// items picked inside folders stay picked).
    private func choose(_ new: Place) {
        let url = url(of: new)
        if let old = pickedPlace { selected.remove(old) }
        pickedPlace = store.contains(url) ? nil : url
        if let picked = pickedPlace { selected.insert(picked) }
        go(new)
    }

    private func go(_ new: Place) {
        guard new != place else { return }
        history.append(place)
        place = new
    }

    private func back() {
        guard let last = history.popLast() else { return }
        place = last
    }

    private func toggle(_ url: URL) {
        guard !store.contains(url) else { return }
        if selected.contains(url) { selected.remove(url); if pickedPlace == url { pickedPlace = nil } }
        else { selected.insert(url) }
    }

    /// Double-click: a folder opens, anything else is added.
    private func openEntry(_ entry: Entry) {
        if entry.isFolder { go(.folder(entry.url)) } else { add([entry.url]) }
    }

    private func add(_ urls: [URL]) {
        urls.forEach { store.add($0, to: category) }
        close()
    }

    private func reload() {
        guard case .folder(let folder) = place else { entries = []; unreadable = false; return }
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys,
                                                                   options: showHidden ? [] : [.skipsHiddenFiles])
            unreadable = false
            entries = urls.map { url in
                let values = try? url.resourceValues(forKeys: Set(keys))
                return Entry(url: url, isFolder: values?.isDirectory == true && values?.isPackage != true)
            }
            .sorted { a, b in
                if a.isFolder != b.isFolder { return a.isFolder }
                return a.url.lastPathComponent.localizedStandardCompare(b.url.lastPathComponent) == .orderedAscending
            }
        } catch {
            entries = []
            unreadable = true
        }
    }
}

/// Same look as a tile in the main panel, with a check mark when picked. A folder shows a small arrow.
private struct FileTile: View {
    let url: URL
    let isFolder: Bool
    let added: Bool
    let selected: Bool
    let toggle: () -> Void
    let open: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 5) {
            Image(nsImage: IconCache.icon(for: url))
                .resizable()
                .interpolation(.high)
                .frame(width: 52, height: 52)
                .overlay(alignment: .topTrailing) {
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white, Color.accentColor)
                            .offset(x: 6, y: -6)
                    }
                }
            Text(IconCache.name(for: url))
                .font(.system(size: 11))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
            Text(added ? "Added" : (isFolder ? "Folder" : " "))
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10)
            .fill(selected ? Color.accentColor.opacity(0.22) : (hovering && !added ? Color.primary.opacity(0.09) : .clear)))
        .opacity(added ? 0.45 : 1)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { toggle() }
        .onDrag { NSItemProvider(object: url as NSURL) }          // drag it into the panel beside this window
        .simultaneousGesture(TapGesture(count: 2).onEnded { if !added || isFolder { open() } })
        .help(url.path)
    }
}
