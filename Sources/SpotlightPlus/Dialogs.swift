import AppKit
import SwiftUI

/// A modal window with a title bar and a close button, shown above the SpotlightPlus panel (which stays
/// visible behind it). Closing it with the red button counts as Cancel.
final class ModalWindow: NSObject, NSWindowDelegate {
    private let window: NSWindow

    init<Content: View>(title: String, @ViewBuilder content: (ModalWindow) -> Content) {
        window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        let host = NSHostingView(rootView: content(self))
        window.contentView = host
        window.setContentSize(host.fittingSize)
        window.title = title
        window.isReleasedWhenClosed = false
        window.level = .modalPanel
        window.delegate = self
    }

    func close() { window.close() }

    func run() {
        PanelController.shared.keepVisible {
            window.center()
            activateSelf()
            NSApp.runModal(for: window)
            window.orderOut(nil)
        }
    }

    func windowWillClose(_ notification: Notification) { NSApp.stopModal() }
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
        VStack(alignment: .leading, spacing: 12) {
            if !message.isEmpty {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }
            TextField("Name", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(submit)
            HStack {
                Spacer()
                Button("Cancel") { done(nil) }.keyboardShortcut(.cancelAction)
                Button(button, action: submit).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 340)
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
                       "/System/Applications/Utilities", "\(home)/Applications"]
        var seen = Set<String>()
        var apps: [URL] = []
        for folder in folders {
            let urls = (try? FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: folder), includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles])) ?? []
            for url in urls where url.pathExtension == "app" && seen.insert(url.path).inserted {
                apps.append(url)
            }
        }
        return apps.sorted { IconCache.name(for: $0).localizedCaseInsensitiveCompare(IconCache.name(for: $1)) == .orderedAscending }
    }
}

enum AppPicker {
    static func show(for category: UUID?) {
        let store = CategoryStore.shared
        let target = category ?? store.essentialsID
        let name = store.categories.first { $0.id == target }?.name ?? "Essentials"
        let modal = ModalWindow(title: "Add Apps to \(name)") { modal in
            AppPickerView(category: target, close: modal.close)
        }
        modal.run()
    }
}

private struct AppPickerView: View {
    let category: UUID
    let close: () -> Void
    @ObservedObject private var store = CategoryStore.shared
    @State private var query = ""
    @State private var selected = Set<URL>()
    @State private var apps = InstalledApps.list()

    private var shown: [URL] {
        query.isEmpty ? apps : apps.filter { IconCache.name(for: $0).localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search apps", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(12)
            List(shown, id: \.self) { url in row(url) }
                .listStyle(.plain)
            Divider()
            HStack {
                Button("Browse…", action: browse)
                Spacer()
                Button("Cancel", action: close).keyboardShortcut(.cancelAction)
                Button(selected.isEmpty ? "Add" : "Add \(selected.count)", action: add)
                    .keyboardShortcut(.defaultAction)
                    .disabled(selected.isEmpty)
            }
            .padding(12)
        }
        .frame(width: 420, height: 520)
    }

    private func row(_ url: URL) -> some View {
        let added = store.contains(url)
        return HStack(spacing: 10) {
            Image(nsImage: IconCache.icon(for: url)).resizable().frame(width: 26, height: 26)
            Text(IconCache.name(for: url))
            Spacer()
            if added {
                Text("Added").font(.caption).foregroundStyle(.secondary)
            } else if selected.contains(url) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
        .opacity(added ? 0.5 : 1)
        .onTapGesture {
            guard !added else { return }
            if selected.contains(url) { selected.remove(url) } else { selected.insert(url) }
        }
    }

    private func add() {
        selected.forEach { store.add($0, to: category) }
        close()
    }

    /// For apps outside the usual folders.
    private func browse() {
        let panel = NSOpenPanel()
        panel.title = "Choose Apps"
        panel.prompt = "Choose"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK {
            panel.urls.forEach { store.add($0, to: category) }
            close()
        }
    }
}
