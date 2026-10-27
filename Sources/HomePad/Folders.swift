import AppKit
import SwiftUI

// Folders of tiles, as in the Windows Start menu. Drop a tile onto the middle of another and the two become a folder;
// its tile shows the first four items, and a click opens it over the panel, where it can be renamed and its items
// opened, rearranged or dragged out. The data lives in CategoryStore (Folder, FolderRef).

/// The open folder, if any.
final class FolderPopup: ObservableObject {
    static let shared = FolderPopup()
    @Published private(set) var openID: UUID?
    /// Where the open folder's card is, in window coordinates (SwiftUI's global space: top left, y down). Read by the
    /// drag watcher: a tile dragged out of the card closes the folder, so it can be dropped among the other tiles.
    var cardFrame = CGRect.zero

    func open(_ id: UUID) {
        WindowPreviewController.shared.hideNow()
        withAnimation(.easeOut(duration: 0.15)) { openID = id }
    }

    func close() {
        guard openID != nil else { return }
        withAnimation(.easeOut(duration: 0.12)) { openID = nil }
    }
}

/// The tile a dragged tile would merge with if dropped now (shown highlighted). Apart from PanelState, so only the
/// tiles redraw when it changes.
final class MergeTarget: ObservableObject {
    static let shared = MergeTarget()
    @Published private(set) var url: URL?

    func set(_ new: URL?) { if url != new { url = new } }
}

/// How long the pointer has been over the edge of one tile. Reordering waits a moment, so that on the way to the middle
/// of a tile (to make a folder) the pointer can cross its edge without the tiles moving away under it.
final class EdgeHover {
    static let shared = EdgeHover()
    private var target: URL?
    private var since = Date()

    /// True once the pointer has rested over this tile's edge long enough.
    func settled(on url: URL) -> Bool {
        if target != url { target = url; since = Date(); return false }
        return Date().timeIntervalSince(since) >= 0.12
    }

    func reset() { target = nil }
}

/// A folder's tile picture: a soft rounded square holding its first four items, small, two by two. The square is the
/// size of an app icon's artwork (app icons leave a transparent margin around it), so it lines up with its neighbours.
struct FolderIcon: View {
    let id: UUID
    var size: CGFloat = 52
    @ObservedObject private var store = CategoryStore.shared

    var body: some View {
        let urls = Array(store.urls(inFolder: id).prefix(4))
        let plate = size * 0.82, gap: CGFloat = 2, inset: CGFloat = 4
        let cell = (plate - 2 * inset - gap) / 2
        ZStack {
            RoundedRectangle(cornerRadius: plate * 0.24, style: .continuous)
                .fill(Color.primary.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: plate * 0.24, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.14), lineWidth: 0.5))
                .frame(width: plate, height: plate)
            VStack(spacing: gap) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<2, id: \.self) { column in
                            let index = row * 2 + column
                            Group {
                                if index < urls.count {
                                    // Icons carry their own transparent margin: drawn a little larger so the artwork
                                    // fills its quarter.
                                    Image(nsImage: IconCache.icon(for: urls[index]))
                                        .resizable()
                                        .interpolation(.high)
                                        .frame(width: cell * 1.18, height: cell * 1.18)
                                } else {
                                    Color.clear
                                }
                            }
                            .frame(width: cell, height: cell)
                        }
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }
}

/// The open folder, drawn over the tiles: its name (click to rename) and its items. A click outside it, or Esc, closes
/// it; dragging an item out of it closes it too, so the item can be dropped among the other tiles.
struct FolderPopupView: View {
    @ObservedObject private var popup = FolderPopup.shared
    @ObservedObject private var store = CategoryStore.shared
    @ObservedObject private var running = RunningApps.shared

    var body: some View {
        if let id = popup.openID, let folder = store.folder(id) {
            ZStack {
                // The tiles behind dim a little; a click there closes the folder.
                Color.black.opacity(0.12)
                    .contentShape(Rectangle())
                    .onTapGesture { popup.close() }
                FolderCard(folder: folder, running: running)
            }
            .transition(.opacity)
        }
    }
}

private struct FolderCard: View {
    let folder: Folder
    @ObservedObject var running: RunningApps
    @ObservedObject private var store = CategoryStore.shared
    @State private var name = ""
    @FocusState private var naming: Bool

    var body: some View {
        let urls = store.urls(inFolder: folder.id)
        let category = store.category(of: FolderRef.url(folder.id))
        // Up to four across, and no wider than its items need (but room for the name).
        let columns = min(max(urls.count, 3), 4)
        let grid = Array(repeating: GridItem(.fixed(TileMetrics.tileWidth), spacing: 8), count: columns)
        VStack(spacing: 10) {
            TextField("Folder name", text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .semibold))
                .multilineTextAlignment(.center)
                .focused($naming)
                .onSubmit { commitName(); naming = false }
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 8).fill(naming ? Color.primary.opacity(0.08) : .clear))
                .help("Click to rename the folder")
            ScrollView {
                LazyVGrid(columns: grid, alignment: .center, spacing: 6) {
                    ForEach(urls, id: \.self) { url in
                        AppTile(url: url, isRunning: running.isRunning(url), categoryID: category, folderID: folder.id).equatable()
                            .onDrag {
                                PanelState.shared.draggingItem = url
                                PanelState.shared.beginDrag()
                                return NSItemProvider(object: url.path as NSString)
                            } preview: {
                                TileIcon(url: url)
                            }
                            .onDrop(of: [.plainText, .fileURL], delegate: TileDropDelegate(target: url, allowsMerge: false))
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(maxHeight: 340)
            .fixedSize(horizontal: false, vertical: urls.count <= columns * 3)
        }
        .padding(16)
        .frame(width: CGFloat(columns) * TileMetrics.tileWidth + CGFloat(columns - 1) * 8 + 40)
        .background(RoundedRectangle(cornerRadius: 18).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
        .background(GeometryReader { geo in
            let _ = { FolderPopup.shared.cardFrame = geo.frame(in: .global) }()
            Color.clear
        })
        // Dropped on the card but not on a tile: to the end of the folder. Finder items dropped here join it too.
        .onDrop(of: [.plainText, .fileURL], delegate: FolderDropDelegate(folder: folder.id))
        .onTapGesture { naming = false }          // a click on the card's background ends renaming, and doesn't close
        .onAppear { name = folder.name }
        .onChange(of: naming) { if !$0 { commitName() } }
        .onDisappear { commitName() }
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }

    private func commitName() {
        store.renameFolder(folder.id, to: name)
        if name.trimmingCharacters(in: .whitespaces).isEmpty { name = folder.name }
    }
}

/// The open folder's card as a drop target: a tile goes to the end of the folder, Finder items join it.
struct FolderDropDelegate: DropDelegate {
    let folder: UUID

    func dropEntered(info: DropInfo) { PanelState.shared.noteDragActivity() }

    func dropUpdated(info: DropInfo) -> DropProposal? { PanelState.shared.noteDragActivity(); return DropProposal(operation: .move) }

    func dropExited(info: DropInfo) { PanelState.shared.noteDragLeft() }

    func performDrop(info: DropInfo) -> Bool {
        let store = CategoryStore.shared
        if let dragging = PanelState.shared.draggingItem {
            if PanelState.shared.tileDragCancelled { PanelState.shared.endDrag(); return true }
            if case .folder(let id)? = store.location(of: dragging)?.container, id == folder {
                // Already in it (rearranged on the way): its place stands.
            } else {
                store.move(dragging, to: .folder(folder))
            }
            PanelState.shared.finishTileDrop()
            return true
        }
        let providers = info.itemProviders(for: [.fileURL])
        FileDrop.load(providers) { urls in
            for url in urls {
                if store.contains(url) { store.move(url, to: .folder(folder)) } else {
                    store.add(url)
                    store.move(url, to: .folder(folder))
                }
            }
        }
        return !providers.isEmpty
    }
}

extension Launcher {
    static func renameFolder(_ id: UUID) {
        guard let folder = CategoryStore.shared.folder(id) else { return }
        DispatchQueue.main.async {
            if let name = TextPrompt.ask(title: "Rename Folder", initial: folder.name, button: "Rename") {
                CategoryStore.shared.renameFolder(id, to: name)
            }
        }
    }
}
