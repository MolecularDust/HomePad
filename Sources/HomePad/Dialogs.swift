import AppKit
import SwiftUI

/// A window with a title bar and a close button, shown in the middle of the screen above the HomePad panel.
/// `run()` blocks until it closes (the panel stays visible behind it); `show()` doesn't, so the window can be
/// moved aside and things dragged from it into the panel. Closing it with the red button counts as Cancel.
final class ModalWindow: NSObject, NSWindowDelegate {
    private static var open: [ModalWindow] = []
    private let window: NSWindow
    private var isModal = false

    /// `resizable` windows can be dragged larger or smaller (down to `minimumSize`); they always open at the size
    /// their content asks for.
    init<Content: View>(title: String, resizable: Bool = false, minimumSize: NSSize = NSSize(width: 520, height: 420),
                        initialSize: NSSize? = nil, @ViewBuilder content: (ModalWindow) -> Content) {
        window = NSWindow(contentRect: .zero, styleMask: resizable ? [.titled, .closable, .resizable] : [.titled, .closable],
                          backing: .buffered, defer: false)
        super.init()
        let host = NSHostingView(rootView: content(self).localized())
        window.contentView = host
        if resizable { window.contentMinSize = minimumSize }
        window.title = title
        // An empty toolbar gives the full-height title bar and traffic lights that regular Mac apps have.
        window.toolbar = NSToolbar(identifier: "ModalWindow")
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.level = .modalPanel
        window.delegate = self
        // Last: adding the toolbar above makes the title bar taller, which would otherwise stretch the content.
        window.setContentSize(initialSize ?? host.fittingSize)
    }

    func close() { window.close() }

    func run() {
        isModal = true
        PanelController.shared.keepVisible {
            window.center()
            activateSelf()
            NSApp.runModal(for: window)
            window.orderOut(nil)
        }
    }

    /// Shows the window without blocking (the panel is kept from hiding while it's open).
    func show() {
        Self.open.append(self)
        PanelController.shared.holdOpen(true)
        window.center()
        activateSelf()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        if isModal { NSApp.stopModal(); return }
        Self.open.removeAll { $0 === self }
        if Self.open.isEmpty { PanelController.shared.holdOpen(false) }
    }
}

// MARK: - Asking for a name

enum TextPrompt {
    /// Returns the trimmed text, or nil if the user cancelled or closed the window.
    static func ask(title: String, message: String = "", initial: String = "", button: String) -> String? {
        var result: String?
        let modal = ModalWindow(title: title) { modal in
            TextPromptView(message: message, initial: initial, button: button) { text in
                result = text
                modal.close()
            }
        }
        modal.run()
        return result
    }
}

private struct TextPromptView: View {
    let message: String
    let button: String
    let done: (String?) -> Void
    @State private var text: String
    @FocusState private var focused: Bool

    init(message: String, initial: String, button: String, done: @escaping (String?) -> Void) {
        self.message = message
        self.button = button
        self.done = done
        _text = State(initialValue: initial)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !message.isEmpty {
                Text(message).font(.system(size: 14)).foregroundStyle(.secondary)
            }
            TextField("Name", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .focused($focused)
                .onSubmit(submit)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.07)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08)))
            HStack(spacing: 10) {
                Spacer()
                Button("Cancel") { done(nil) }.keyboardShortcut(.cancelAction)
                Button(button, action: submit).keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
        }
        .padding(28)
        .frame(width: 520)
        .onAppear { DispatchQueue.main.async { focused = true } }
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { NSSound.beep() } else { done(trimmed) }
    }
}

// MARK: - Picking apps

enum InstalledApps {
    /// Apps in the usual folders, sorted by name.
    static func list() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let folders = ["/Applications", "/Applications/Utilities", "/System/Applications",
                       "/System/Applications/Utilities", "/System/Cryptexes/App/System/Applications",
                       "\(home)/Applications"]
        var seen = Set<String>()
        var apps: [URL] = []
        for folder in folders {
            // No skipsHiddenFiles: Safari is a hidden link in /Applications.
            let urls = (try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: folder),
                                                                     includingPropertiesForKeys: nil)) ?? []
            for url in urls where url.pathExtension == "app" && !url.lastPathComponent.hasPrefix(".")
                && seen.insert(url.resolvingSymlinksInPath().path).inserted {
                apps.append(url)
            }
        }
        return apps.sorted { IconCache.name(for: $0).localizedCaseInsensitiveCompare(IconCache.name(for: $1)) == .orderedAscending }
    }
}

enum AppPicker {
    static func show(for category: UUID?) {
        show(to: .category(category ?? CategoryStore.shared.essentialsID))
    }

    static func show(to target: PinTarget) {
        let title: String
        switch target {
        case .category(let id):
            let name = CategoryStore.shared.categories.first { $0.id == id }?.name ?? L("Essentials")
            title = L("Add Apps to \(name)")
        case .taskbar:
            title = L("Add Apps to the Taskbar")
        }
        let modal = ModalWindow(title: title, resizable: true, initialSize: panelSize) { modal in
            AppPickerView(target: target, close: modal.close)
        }
        modal.show()
    }
}

private struct AppPickerView: View {
    let target: PinTarget
    let close: () -> Void
    @ObservedObject private var store = CategoryStore.shared
    @ObservedObject private var pins = TaskbarPins.shared
    @AppStorage("columns") private var columns = 8
    @State private var query = ""
    @State private var selected = Set<URL>()
    @State private var apps = InstalledApps.list()
    @FocusState private var searchFocused: Bool

    private var shown: [URL] {
        query.isEmpty ? apps : apps.filter { IconCache.name(for: $0).localizedCaseInsensitiveContains(query) }
    }

    private var grid: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: max(columns, 3))
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 14)

            ScrollView {
                LazyVGrid(columns: grid, spacing: 6) {
                    ForEach(shown, id: \.self) { url in
                        PickerTile(url: url, added: target.contains(url), selected: selected.contains(url),
                                   toggle: {
                                       // Check the live state: a double-click delivers its clicks after the pin.
                                       guard !target.contains(url) else { return }
                                       if selected.contains(url) { selected.remove(url) } else { selected.insert(url) }
                                   },
                                   pin: {
                                       guard !target.contains(url) else { return }
                                       selected.remove(url)
                                       target.add(url)
                                       close()          // so the new tile is visible in the panel behind
                                   })
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            Divider().opacity(0.6)
            footer
        }
        .frame(minWidth: 520, idealWidth: panelSize.width, maxWidth: .infinity,
               minHeight: 420, idealHeight: panelSize.height, maxHeight: .infinity)
        .onAppear { DispatchQueue.main.async { searchFocused = true } }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search apps", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .focused($searchFocused)
            if !query.isEmpty {
                Button { query = "" } label: {
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
            Button("Browse…", action: browse)
            Text("Double-click an app to add it and close")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Button("Cancel", action: close).keyboardShortcut(.cancelAction)
            Button(selected.isEmpty ? "Add" : "Add \(selected.count)", action: add)
                .keyboardShortcut(.defaultAction)
                .disabled(selected.isEmpty)
        }
        .padding(.horizontal, 24)
        .frame(height: 52)
        .background(Color.primary.opacity(0.03))
    }

    private func add() {
        selected.forEach { target.add($0) }
        close()
    }

    /// For apps outside the usual folders.
    private func browse() {
        let panel = NSOpenPanel()
        panel.title = L("Choose Apps")
        panel.prompt = L("Choose")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK {
            panel.urls.forEach { target.add($0) }
            close()
        }
    }
}

/// Same look as a tile in the main panel, with a check mark when picked.
private struct PickerTile: View {
    let url: URL
    let added: Bool
    let selected: Bool
    let toggle: () -> Void
    let pin: () -> Void          // double-click: add straight away
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 5) {
            TileIcon(url: url, picked: selected)
            Text(IconCache.name(for: url))
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 4)
            Text(added ? "Added" : " ")
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
        .simultaneousGesture(TapGesture(count: 2).onEnded { pin() })
        .help(IconCache.name(for: url))
    }
}
