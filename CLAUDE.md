# HomePad for macOS

A Windows 11–style launcher for macOS, built as a Swift Package. A global shortcut (default
Option-Space) pops up a centered panel with a search bar (backed by the Spotlight index) above a grid
of pinned apps. The grid is meant to replace the Dock: apps live in user-defined categories (Essentials first, seeded from the
Dock on first launch, plus custom ones), with a read-only Running section. See [README.md](README.md) for user-facing behavior.

## Technical facts

- Targets **macOS 13+** (`Package.swift`: `.macOS(.v13)`, swift-tools-version 5.9). Pure SwiftUI + AppKit, no dependencies.
- Runs as a menu-bar app with **`LSUIElement`** (no Dock icon; `main.swift` also sets `.accessory` activation policy).
- **Unsandboxed.** It reads the Dock's prefs, runs `defaults`/`killall Dock`, and searches the whole index, which a sandbox would block.
- Distributed **outside the App Store**; `build_app.sh` ad-hoc signs (`codesign --sign -`), so first launch may need right-click → Open.
- Global shortcut uses Carbon **`RegisterEventHotKey`** (no Accessibility permission needed).
- Search uses **`NSMetadataQuery`** (Spotlight index), debounced 80 ms, scope `NSMetadataQueryLocalComputerScope`.
- Initial pinned list comes from the Dock's **`com.apple.dock` `persistent-apps`** preference (via `CFPreferences`), Finder prepended.
- "Hide the Dock" sets `autohide` + `autohide-delay=1000` in `com.apple.dock` and restarts the Dock.
- Launch at login via `SMAppService.mainApp`. Settings are stored in `UserDefaults` (`categories`, `columns`, `showRunning`, `hotkey*`, `doubleTapKey`, `hotCorners`, `folders` as "topLeft,bottomRight"). Bundle id is `local.mike.HomePad`.
- Permissions (prompted at runtime): Screen Recording (window thumbnails), Accessibility (raise or close a specific window, double-tap trigger), Full Disk Access (no API to request it; without it NSMetadataQuery silently omits files in Documents, Desktop and Downloads). Ad-hoc signing means macOS may re-ask after a rebuild.

## Layout

| File (`Sources/HomePad/`) | What it does |
|---|---|
| `main.swift`, `AppDelegate.swift` | App startup, menu-bar icon, settings window |
| `Trigger.swift` | Double-tap-modifier trigger (global `NSEvent` monitor), `LegacyMigration` from the earlier bundle ids `local.mike.SpotlightPlus` and `local.mike.StartMenu` |
| `HotCorners.swift` | `HotCorner` (frame in a corner, macOS's own `wvous-*` corner action for the clash warning) and `HotCornerMonitor`: polls `NSEvent.mouseLocation` at 20 Hz only while a corner is chosen (no permission needed), 0.2 s dwell, re-arms after leaving by 40 pt, ignores drags; opens the panel in that corner |
| `Folders.swift` | Windows-style folders: `FolderPopup` (the open folder over the tiles; a tile dragged out of its card closes it), `MergeTarget` (the tile a drop would merge with), `EdgeHover` (reorder waits 0.12 s over a tile's edge so the pointer can reach its middle), `FolderIcon` (2×2 minis), the popup card and its drop delegate. Data: `Folder` / `FolderRef` / `Container` in Model.swift; a folder sits in a category's `paths` as "homepad-folder:<id>", saved under `folders`; one item left → it becomes that item (held off during a drag, `holdsFolders`) |
| `ShortcutConflict.swift` | Detects who else uses the global shortcut (macOS shortcuts exactly, known launcher apps as a guess) and shows the explanation dialog; Carbon registration does NOT fail on clashes |
| `Onboarding.swift` | First-run welcome window (permissions + shortcut); reopen via menu bar → Setup Guide… |
| `FilePicker.swift` | "Add File or Folder": our own file browser window (sidebar, grid, back, hidden-items toggle) with a Trash entry; `~/.Trash` is hidden so the system open dialog never shows it |
| `Dialogs.swift` | `ModalWindow` (titled, closable, runs via `NSApp.runModal`), `TextPrompt`, `AppPicker`; replaces NSAlert/NSOpenPanel so dialogs have a close button |
| `Spaces.swift` | Private SkyLight calls, looked up with `dlsym`: which Space a window is on (hidden helper windows are on none), bringing a window forward, and `RemoteAX` (Accessibility elements for windows on other Spaces, found by scanning element ids; windows sit at ids in the thousands). OK because the app is unsandboxed and not on the App Store |
| `Windows.swift` | Permissions, window thumbnails (ScreenCaptureKit; needs macOS 14 for images), hover popup panel, jump to window via Accessibility |
| `HotKey.swift` | Global shortcut (Carbon `RegisterEventHotKey`), `Shortcut` model + persistence |
| `Panel.swift` | The centered floating `NSPanel` and its keyboard handling |
| `HomePadView.swift` | The UI: search bar, category grids, placeholder tiles, running apps, results list |
| `Calculator.swift` | Arithmetic typed in the search field (hand-written parser, not NSExpression, which throws on bad input); result card appears first |
| `Search.swift` | Spotlight-index search via `NSMetadataQuery` |
| `Model.swift` | Dock import, `CategoryStore` (categories, persisted as JSON), running apps, launching, Dock hiding |
| `SettingsView.swift` | Settings and the shortcut recorder |

`activateSelf()` uses `NSApp.activate(ignoringOtherApps:)` on purpose: the cooperative `NSApp.activate()` is often refused on macOS 14+, and then the panel opens without keyboard focus.

Pop-ups must go through `PanelController.keepVisible` so the panel stays visible behind them.

Other top-level files: `Package.swift`, `build_app.sh` (`UNIVERSAL=1` for arm64 + x86_64), `README.md`, `INSTALL.md` (install guide for friends; keep it in step with the Setup Guide and Settings wording). `tools/make_release.sh` zips the universal app with `INSTALL.md` into `dist/HomePad.zip` (git-ignored). The app icon is `Resources/AppIcon.svg`; `tools/make_icon.sh` renders it into `Resources/AppIcon.icns`, which `build_app.sh` copies into the bundle (`CFBundleIconFile`).

## Build

```
./build_app.sh      # release build + assembles "build/HomePad.app" (Info.plist, ad-hoc codesign)
swift build         # compile only (debug)
```

`build_app.sh` stamps the real SDK version into the binary (`-platform_version macos 13.0 <sdk>`); SwiftPM alone records SDK 13.0, which makes macOS draw the app in an older compatibility look (small traffic lights). Check with `otool -l ... | grep -A4 LC_BUILD_VERSION`.

Output is `build/HomePad.app`; `.build/` and `build/` are git-ignored. To work in Xcode, open `Package.swift`.
