# Start Menu for macOS

A Windows 11–style Start menu for macOS, built as a Swift Package. A global shortcut (default
Option-Space) pops up a centered panel with a search bar (backed by the Spotlight index) above a grid
of pinned apps. The pinned grid is meant to replace the Dock: on first launch it is seeded from the
Dock's pinned apps, after which it is its own unlimited list. See [README.md](README.md) for user-facing behavior.

## Technical facts

- Targets **macOS 13+** (`Package.swift`: `.macOS(.v13)`, swift-tools-version 5.9). Pure SwiftUI + AppKit, no dependencies.
- Runs as a menu-bar app with **`LSUIElement`** (no Dock icon; `main.swift` also sets `.accessory` activation policy).
- **Unsandboxed.** It reads the Dock's prefs, runs `defaults`/`killall Dock`, and searches the whole index, which a sandbox would block.
- Distributed **outside the App Store**; `build_app.sh` ad-hoc signs (`codesign --sign -`), so first launch may need right-click → Open.
- Global shortcut uses Carbon **`RegisterEventHotKey`** (no Accessibility permission needed).
- Search uses **`NSMetadataQuery`** (Spotlight index), debounced 80 ms, scope `NSMetadataQueryLocalComputerScope`.
- Initial pinned list comes from the Dock's **`com.apple.dock` `persistent-apps`** preference (via `CFPreferences`), Finder prepended.
- "Hide the Dock" sets `autohide` + `autohide-delay=1000` in `com.apple.dock` and restarts the Dock.
- Launch at login via `SMAppService.mainApp`. Settings are stored in `UserDefaults` (`pinnedPaths`, `columns`, `showRunning`, `hotkey*`).

## Layout

| File (`Sources/StartMenu/`) | What it does |
|---|---|
| `main.swift`, `AppDelegate.swift` | App startup, menu-bar icon, settings window |
| `HotKey.swift` | Global shortcut (Carbon `RegisterEventHotKey`), `Shortcut` model + persistence |
| `Panel.swift` | The centered floating `NSPanel` and its keyboard handling |
| `StartMenuView.swift` | The UI: search bar, pinned grid, running apps, results list |
| `Search.swift` | Spotlight-index search via `NSMetadataQuery` |
| `Model.swift` | Dock import, pinned list, running apps, launching, Dock hiding |
| `SettingsView.swift` | Settings and the shortcut recorder |

Other top-level files: `Package.swift`, `build_app.sh`, `README.md`.

## Build

```
./build_app.sh      # release build + assembles "build/Start Menu.app" (Info.plist, ad-hoc codesign)
swift build         # compile only (debug)
```

Output is `build/Start Menu.app`; `.build/` and `build/` are git-ignored. To work in Xcode, open `Package.swift`.
