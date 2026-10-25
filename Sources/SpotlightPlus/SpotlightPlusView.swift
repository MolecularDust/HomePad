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
        .onHover { hovering = $0 && !PanelState.shared.isDragging }
        .accessibilityLabel(name)
        .overlay(alignment: .topTrailing) { if hovering { HoverLabel(text: name).offset(y: -30) } }
        .zIndex(1)
    }
}

/// The small label above a footer button, shown at once under the pointer.
struct HoverLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(.regularMaterial))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
            .fixedSize()
            .allowsHitTesting(false)
    }
}

/// An item's icon at tile size, with a check mark when it is picked (in the Add windows).
struct TileIcon: View {
    let url: URL
    var picked = false

    var body: some View {
        Image(nsImage: IconCache.icon(for: url))
            .resizable()
            .interpolation(.high)
            .frame(width: 52, height: 52)
            .overlay(alignment: .topTrailing) {
                if picked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white, Color.accentColor)
                        .offset(x: 6, y: -6)
                }
            }
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
        .onHover { hovering = $0 && !PanelState.shared.isDragging }
        .accessibilityLabel("Apple Account")
        .overlay(alignment: .topLeading) { if hovering { HoverLabel(text: "Apple Account").offset(y: -34) } }
        .zIndex(1)
    }
}

/// Moves the panel when an empty part of it is dragged. The window's own drag-by-background doesn't reach the
/// areas SwiftUI draws (the lists, the footer), so once a drag starts there it is handed to the window server, which
/// moves the window itself, in step with the pointer. Tiles and buttons have their own gestures, which take precedence.
private final class MoveDrag { var active = false }

struct MovesWindowWhenDragged: ViewModifier {
    @State private var drag = MoveDrag()

    func body(content: Content) -> some View {
        content.gesture(DragGesture(minimumDistance: 4)
            .onChanged { _ in
                guard !drag.active, RowDrag.shared.pressed == nil else { return }    // a category row is carried instead
                guard let event = NSApp.currentEvent, event.type == .leftMouseDragged else { return }
                drag.active = true
                PanelController.shared.performDrag(with: event)       // returns when the mouse button comes up
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
        .onHover { hovering = $0 && !PanelState.shared.isDragging }
    }
}

// MARK: - Categories + running apps

/// The "Row height" setting: the distance in points from one row of tiles to the next. 101 is the standard layout.
/// A tile's icon, running mark and name take about 79 pt and 6 pt separates the rows; the rest is padding above and
/// below each tile.
enum RowMetrics {
    static let standard = 101
    static let range = 85...125
    private static let tileContent: CGFloat = 79, rowGap: CGFloat = 6

    static func padding(_ rowHeight: Int) -> CGFloat { max(0, (CGFloat(rowHeight) - tileContent - rowGap) / 2) }

    /// How far the green selection box reaches past a category's contents, on every side.
    static let selectionOutset: CGFloat = 6

    /// The space between categories, with the separator line in its middle. It follows the row height so the layout
    /// loosens or tightens together, but never gets so small that the selection box (which reaches `selectionOutset`
    /// into it from either side) touches the line: at least 4 pt stay clear on each side of it.
    static func categoryGap(_ rowHeight: Int) -> CGFloat {
        let minimum = (selectionOutset + 4) * 2
        return min(26, max(minimum, 22 + CGFloat(rowHeight - standard) * 0.4))
    }
}

/// The "Icon spacing" setting: the horizontal gap in points between neighbouring tiles. Tiles have a fixed width and
/// rows start at the left, so the gap really shows (when columns stretch to fill the panel, the distance between
/// icons only depends on the panel's width). A row that wouldn't fit gives up gap first, then tile width.
enum TileMetrics {
    static let standardSpacing = 10
    static let spacingRange = 0...40
    static let tileWidth: CGFloat = 76          // the 52 pt icon plus room for its name

    static func columns(count: Int, spacing: Int, width available: CGFloat) -> [GridItem] {
        let count = max(count, 3)
        let gaps = CGFloat(count - 1)
        let gap = min(CGFloat(spacing), max(0, (available - CGFloat(count) * tileWidth) / gaps))
        let tile = min(tileWidth, (available - gap * gaps) / CGFloat(count))
        return Array(repeating: GridItem(.fixed(max(tile, 40)), spacing: gap), count: count)
    }
}

struct RowFramesKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) { value.merge(nextValue()) { $1 } }
}

extension View {
    /// A thin gray line in the gap above this view, which separates it from the one before. Drawn outside the layout
    /// so that every category row measures the same.
    func separatedAbove(_ show: Bool, gap: CGFloat) -> some View {
        overlay(alignment: .top) {
            if show { Rectangle().fill(Color.gray.opacity(0.28)).frame(height: 1).offset(y: -gap / 2 - 0.5).allowsHitTesting(false) }
        }
    }
}

/// Draws a category row where the drag puts it. Only this small view watches the drag, so a mouse move redraws
/// nothing but the rows' positions.
struct CarriedRow<Content: View>: View {
    let id: UUID
    @ViewBuilder let content: Content
    @ObservedObject private var drag = RowDrag.shared

    var body: some View {
        let carried = drag.carried == id
        let selected = drag.pressed == id
        content
            .padding(RowMetrics.selectionOutset)
            .background {
                // Solid underneath the green tint, so a carried row hides the rows it passes over.
                if selected {
                    RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .windowBackgroundColor))
                        .overlay(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.12)))
                }
            }
            .overlay { if selected { RoundedRectangle(cornerRadius: 12).stroke(Color.green, lineWidth: 2) } }
            .padding(-RowMetrics.selectionOutset)
            .offset(y: drag.shift(for: id))
            .animation(carried ? nil : .easeInOut(duration: 0.18), value: drag.target)    // the others slide; the carried one sticks to the pointer
            .zIndex(carried ? 1 : 0)
    }
}

struct HomeView: View {
    @ObservedObject private var store = CategoryStore.shared
    @ObservedObject private var running = RunningApps.shared
    @AppStorage("columns") private var columns = 8
    @AppStorage("showRunning") private var showRunning = true
    @AppStorage("rowHeight") private var rowHeight = RowMetrics.standard
    @AppStorage("iconSpacing") private var iconSpacing = TileMetrics.standardSpacing

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
                let grid = TileMetrics.columns(count: columns, spacing: iconSpacing, width: geo.size.width - 48)    // 24 pt margins
                ScrollView {
                    VStack(alignment: .leading, spacing: RowMetrics.categoryGap(rowHeight)) {
                        // The categories and the Running section, in the order they were put in.
                        let rows = store.rows(includingRunning: showRunning && !runningApps.isEmpty)
                        ForEach(Array(rows.enumerated()), id: \.element) { index, id in
                            CarriedRow(id: id) {
                                Group {
                                    if id == CategoryStore.runningID {
                                        RunningSection(apps: runningApps, grid: grid)
                                    } else if let category = store.categories.first(where: { $0.id == id }) {
                                        CategorySection(category: category, grid: grid, running: running)
                                    }
                                }
                                .separatedAbove(index > 0, gap: RowMetrics.categoryGap(rowHeight))
                                .background(GeometryReader { geo in
                                    Color.clear.preference(key: RowFramesKey.self, value: [id: geo.frame(in: .named("rows"))])
                                })
                            }
                        }
                    }
                    .coordinateSpace(name: "rows")
                    .onPreferenceChange(RowFramesKey.self) { frames in
                        if PanelState.shared.draggingCategory == nil { RowDrag.shared.frames = frames }     // where the rows rest, not where one is carried
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    // Fill the whole scroll area so a right-click on empty space lands here.
                    .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .topLeading)
                    .contentShape(Rectangle())
                    .movesWindowWhenDragged()          // inside the scroll view, which takes its own mouse events
                    .contextMenu {
                        // Outside every row (below the last one): into Essentials.
                        Button("Add App to \(store.essentialsName)…") { Launcher.chooseAppsToPin() }
                        Button("Add File or Folder to \(store.essentialsName)…") { Launcher.chooseFilesToPin() }
                        Divider()
                        Button("Add Category…") { Launcher.addCategory() }
                    }
                }
            }
        }
    }
}

/// A row's name (a category, or Running). It turns green under the pointer. Dragging it picks up the whole row (the
/// name and its icons) and moves it to another place among the rows.
struct RowTitle: View {
    let id: UUID
    let name: String
    @State private var hovering = false

    var body: some View {
        Text(name)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(hovering ? Color.green : Color.primary)
            .contentShape(Rectangle())
            .overlay(RowDragHandle(id: id))
            .onHover { hovering = $0 && !PanelState.shared.isDragging }      // after the overlay: the drag layer sits on top of the name
            .help("Drag to move this section")
    }
}

/// Move Up / Move Down for a row's right-click menu, offered only where there is room to move.
struct MoveRowItems: View {
    let id: UUID
    let name: String
    @ObservedObject private var store = CategoryStore.shared

    var body: some View {
        let rows = store.visibleRows
        let position = rows.firstIndex(of: id) ?? 0
        if position > 0 {
            Button("Move \(name) Up") { withAnimation(.easeInOut(duration: 0.2)) { store.moveRow(id, by: -1) } }
        }
        if position < rows.count - 1 {
            Button("Move \(name) Down") { withAnimation(.easeInOut(duration: 0.2)) { store.moveRow(id, by: 1) } }
        }
    }
}

/// Every running app, pinned or not, like the Dock's running indicators. Its contents follow the apps that are
/// running, so it can't be added to, renamed or deleted, but it can be moved among the categories.
struct RunningSection: View {
    let apps: [URL]
    let grid: [GridItem]
    @ObservedObject private var store = CategoryStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                RowTitle(id: CategoryStore.runningID, name: "Running")
                Spacer()
                Label("Managed automatically", systemImage: "lock")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            LazyVGrid(columns: grid, alignment: .leading, spacing: 6) {
                ForEach(apps, id: \.self) { url in
                    AppTile(url: url, isRunning: true, categoryID: nil).equatable()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .movesWindowWhenDragged()
        .contextMenu {
            // Nothing can be added to Running itself, so adding goes to Essentials, as below the last row.
            Button("Add App to \(store.essentialsName)…") { Launcher.chooseAppsToPin() }
            Button("Add File or Folder to \(store.essentialsName)…") { Launcher.chooseFilesToPin() }
            Divider()
            Button("Add Category…") { Launcher.addCategory() }
            MoveRowItems(id: CategoryStore.runningID, name: "Running")
        }
    }
}

/// An invisible layer over a row's name. Pressing it selects the whole row; dragging it carries the row itself
/// (the other rows slide aside to make room) and letting go drops it in the place it has reached.
struct RowDragHandle: NSViewRepresentable {
    let id: UUID

    func makeNSView(context: Context) -> RowDragSourceView { RowDragSourceView() }

    func updateNSView(_ view: RowDragSourceView, context: Context) { view.id = id }
}

final class RowDragSourceView: NSView {
    var id = UUID()

    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Follows the mouse itself until the button comes up. Taking every drag event here keeps them from SwiftUI,
    /// whose window-moving gesture would otherwise move the whole panel along with the row.
    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let state = PanelState.shared
        let drag = RowDrag.shared
        drag.press(id)
        let startY = event.locationInWindow.y
        var carrying = false
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp], until: .distantFuture, inMode: .default, dequeue: true), next.type == .leftMouseDragged {
            let offset = startY - next.locationInWindow.y          // window coordinates grow upwards
            if !carrying {
                guard abs(offset) > 3 else { continue }
                carrying = true
                state.draggingCategory = id
                state.beginDrag()
                drag.begin(id)
            }
            drag.move(to: offset)
        }
        if carrying { state.dropCarriedRow() } else { drag.press(nil) }
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
            RowTitle(id: category.id, name: category.name)

            LazyVGrid(columns: grid, alignment: .leading, spacing: 6) {
                ForEach(urls, id: \.self) { url in
                    AppTile(url: url, isRunning: running.isRunning(url), categoryID: category.id).equatable()
                        .onDrag {
                            PanelState.shared.draggingItem = url
                            PanelState.shared.beginDrag()
                            return NSItemProvider(object: url.path as NSString)
                        } preview: {
                            // Just the icon under the pointer (by default it was a picture of the whole tile, hover
                            // highlight and name included), above the empty slot it leaves behind.
                            TileIcon(url: url)
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
            MoveRowItems(id: category.id, name: category.name)
            Button("Rename \(category.name)…") { Launcher.renameCategory(category) }
            if category.id != store.essentialsID {
                Button("Delete \(category.name)") { store.delete(category.id) }
            }
        }
    }
}

/// Where a tile is, for placing the window popup next to it. A plain box rather than view state: it changes whenever
/// tiles move (resizing the panel moved and rebuilt every tile), and is only needed when the pointer arrives.
private final class FrameBox { var rect = CGRect.zero }

/// categoryID is nil for tiles in the Running section, which can't be edited.
/// Compared by what it shows, so a category redrawn for another reason (the panel being resized) skips its unchanged
/// tiles; changes the tile watches itself (hover, row height, the Close Windows check) still redraw it.
struct AppTile: View, Equatable {
    static func == (a: AppTile, b: AppTile) -> Bool { a.url == b.url && a.isRunning == b.isRunning && a.categoryID == b.categoryID }

    let url: URL
    @AppStorage("rowHeight") private var rowHeight = RowMetrics.standard
    let isRunning: Bool
    let categoryID: UUID?
    @State private var hovering = false
    @State private var frame = FrameBox()
    @ObservedObject private var closable = ClosableWindows.shared
    @ObservedObject private var tileDrag = TileDrag.shared
    @ObservedObject private var appMenus = AppMenus.shared

    var body: some View {
        // While this tile is being dragged, its place is an empty slot (moving along as the others make room), and
        // the icon lands in it when dropped. Name and running mark keep their space, so nothing shifts.
        let inTheAir = tileDrag.item == url && categoryID != nil
        // The running mark right under the icon, and the name under that, so the mark stays clear of the text.
        // The mark sits close under the icon's artwork and further from the name, so it reads as the icon's. (App icons
        // keep a transparent margin of about 5 pt below the artwork, so the mark goes up into it.)
        VStack(spacing: 0) {
            if inTheAir { DashedSlot() } else { TileIcon(url: url) }
            RoundedRectangle(cornerRadius: 1.5)
                .fill(isRunning && !inTheAir ? Color.red : Color.clear)
                .frame(width: 18, height: 3)
                .padding(.top, -3)
                .padding(.bottom, 13)
            Text(IconCache.name(for: url))
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 4)
                .opacity(inTheAir ? 0 : 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, RowMetrics.padding(rowHeight))
        .background(RoundedRectangle(cornerRadius: 10).fill(hovering && !inTheAir ? Color.primary.opacity(0.09) : .clear))
        // Written straight into the box as the tile is laid out. (Passed up as a preference, the change handler
        // stopped being called once the tile no longer rebuilt, and the popup was placed at the panel's corner.)
        .background(GeometryReader { geo in
            let _ = { frame.rect = geo.frame(in: .global) }()
            Color.clear
        })
        .contentShape(Rectangle())
        .onHover { inside in
            guard !PanelState.shared.isDragging else { hovering = false; return }      // passing over it with something in hand
            hovering = inside
            if isRunning {
                if inside {                                         // so its menu is current by the time it's right-clicked
                    ClosableWindows.shared.refresh()
                    if let app = RunningApps.shared.app(for: url) { AppMenus.shared.refresh(app) }
                }
                WindowPreviewController.shared.hover(app: RunningApps.shared.app(for: url), over: inside, tile: frame.rect)
            }
        }
        .onTapGesture { Launcher.open(url) }
        .help(IconCache.name(for: url))
        .contextMenu {
            // Laid out like the Dock's menu. A running app's windows and "New …" commands come from what was read in the
            // background when the pointer arrived (see AppMenus); asking the app here would hold up drawing the tile.
            let app = isRunning ? RunningApps.shared.app(for: url) : nil
            let menu = app.flatMap { appMenus.info[$0.processIdentifier] }
            if let app, let menu, !menu.windows.isEmpty {
                ForEach(menu.windows) { window in
                    // A checkable item, so the window in front shows the menu's own check mark; choosing any of them
                    // brings that window forward.
                    Toggle(window.title, isOn: Binding(get: { window.isMain }, set: { _ in
                        WindowCatalog.focus(AppWindow(id: window.id, title: window.title, frame: window.frame,
                                                      onOtherSpace: window.onOtherSpace), of: app)
                    }))
                }
                Divider()
            }
            if let app, let menu, !menu.commands.isEmpty {
                ForEach(menu.commands) { command in Button(command.title) { AppMenus.run(command, of: app) } }
                Divider()
            }
            if app == nil { Button("Open") { Launcher.open(url) } }
            if url.path != trashURL.path { Button("Show in Finder") { Launcher.reveal(url) } }
            if let categoryID {
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
                // Read from what the background check last found: asking the app here would wait for its answer
                // every time the tile is drawn, since SwiftUI builds this menu along with the tile.
                if let app, closable.pids.contains(app.processIdentifier) {
                    Button("Close Windows") { Launcher.closeWindows(url) }
                }
                Button("Hide") { Launcher.hide(url) }
                if Launcher.canQuit(url) {
                    Button("Quit") { Launcher.quit(url) }            // Force Quit with Option held
                }
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
/// The dashed square with a plus: an empty category's stand-in, and the place a dragged icon will land.
struct DashedSlot: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .foregroundStyle(.quaternary)
            Image(systemName: "plus").font(.system(size: 18)).foregroundStyle(.tertiary)
        }
        .frame(width: 52, height: 52)
    }
}

struct PlaceholderTile: View {
    let categoryID: UUID
    @AppStorage("rowHeight") private var rowHeight = RowMetrics.standard

    var body: some View {
        VStack(spacing: 0) {
            DashedSlot()
            Color.clear.frame(width: 18, height: 3).padding(.top, -3).padding(.bottom, 13)
            Text("Add your app here")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, RowMetrics.padding(rowHeight))
        .contentShape(Rectangle())
        .onTapGesture { Launcher.chooseAppsToPin(to: categoryID) }
    }
}

/// Drag a tile over another to reorder (or move it into that tile's category); drop a Finder item on a tile to insert it there.
struct TileDropDelegate: DropDelegate {
    let target: URL

    func dropEntered(info: DropInfo) {
        PanelState.shared.noteDragActivity()
        let store = CategoryStore.shared
        guard !PanelState.shared.tileDragCancelled, let dragging = PanelState.shared.draggingItem, dragging != target,
              let to = store.location(of: target) else { return }
        withAnimation(.easeInOut(duration: 0.15)) { store.move(dragging, toCategory: to.category, at: to.index) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { PanelState.shared.noteDragActivity(); return DropProposal(operation: .move) }

    func dropExited(info: DropInfo) { PanelState.shared.noteDragLeft() }

    func performDrop(info: DropInfo) -> Bool {
        if PanelState.shared.draggingItem != nil {
            // After Esc nothing lands: ending the drag puts the tile back.
            if PanelState.shared.tileDragCancelled { PanelState.shared.endDrag() } else { PanelState.shared.finishTileDrop() }
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

    func dropEntered(info: DropInfo) { PanelState.shared.noteDragActivity() }

    func dropUpdated(info: DropInfo) -> DropProposal? { PanelState.shared.noteDragActivity(); return DropProposal(operation: .move) }

    func dropExited(info: DropInfo) { PanelState.shared.noteDragLeft() }

    func performDrop(info: DropInfo) -> Bool {
        if let dragging = PanelState.shared.draggingItem {
            if PanelState.shared.tileDragCancelled { PanelState.shared.endDrag(); return true }
            CategoryStore.shared.move(dragging, toCategory: category)
            PanelState.shared.finishTileDrop()
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
    @ObservedObject private var permissions = PermissionStatus.shared

    var body: some View {
        if !permissions.fullDiskAccess && !hidden {
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
