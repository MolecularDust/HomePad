# Start Menu for macOS

A Windows 11–style Start menu: press a shortcut and a panel pops up in the middle of the screen with a
search bar on top (searching the same index Spotlight uses) and a grid of pinned apps below.

## Build and run

Requires macOS 13 or later and Xcode or the Command Line Tools (`xcode-select --install`).

```
cd StartMenu
chmod +x build_app.sh
./build_app.sh
```

This creates `build/Start Menu.app`. Move it to **/Applications** and open it. Because it's signed
locally rather than by a registered developer, the first launch may need right-click → Open.

It runs as a menu-bar app (grid icon in the menu bar), with no Dock icon of its own.
To work on the code in Xcode instead, open `Package.swift` in Xcode and press Run.

## Using it

- **Option-Space** opens and closes the panel (change it in Settings).
- **Pinned grid**: on first launch it copies your Dock's apps, Finder first. After that the list is
  its own and has no size limit. Click to launch an app, or switch to it if it's already running.
  A small dot under an icon means the app is running.
- **Add**: the Add App button, drag apps or files in from Finder (press the shortcut mid-drag), or
  right-click any search result → Pin to Start.
- **Remove / reorder**: right-click a tile → Unpin / Move Left / Move Right, or drag tiles around.
- **Search**: just start typing. Apps come first, then documents and folders, then a web search.
  ↑ ↓ to choose, ↩ to open, ⌘↩ to show in Finder, Esc to clear and then close.
- **Running**: apps that are open but not pinned show in a section under the grid (can be turned off).

## Settings

- **Shortcut**: click the button and press a new combination. To use ⌘Space, first turn off
  Spotlight's shortcut in System Settings → Keyboard → Keyboard Shortcuts → Spotlight.
- **Icons per row**, **show running apps**, **re-import from Dock**.
- **Hide the Dock**: turns on Dock auto-hide with a 1000-second delay so it never appears.
  Turning it off restores the normal Dock.
- **Launch at login**.

## Files

| File | What it does |
|---|---|
| `main.swift`, `AppDelegate.swift` | App startup, menu-bar icon, settings window |
| `HotKey.swift` | Global shortcut (Carbon `RegisterEventHotKey`, no permissions needed) |
| `Panel.swift` | The centered floating window and its keyboard handling |
| `StartMenuView.swift` | The UI: search bar, pinned grid, running apps, results list |
| `Search.swift` | Spotlight-index search via `NSMetadataQuery` |
| `Model.swift` | Dock import, pinned list, running apps, launching, Dock hiding |
| `SettingsView.swift` | Settings and the shortcut recorder |
