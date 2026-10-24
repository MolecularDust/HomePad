# SpotlightPlus for macOS

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
- Launch at login via `SMAppService.mainApp`. Settings are stored in `UserDefaults` (`categories`, `columns`, `showRunning`, `hotkey*`, `doubleTapKey`). Bundle id is `local.mike.SpotlightPlus`.
- Permissions (prompted at runtime): Screen Recording (window thumbnails), Accessibility (raise or close a specific window, double-tap trigger), Full Disk Access (no API to request it; without it NSMetadataQuery silently omits files in Documents, Desktop and Downloads). Ad-hoc signing means macOS may re-ask after a rebuild.

## Layout

| File (`Sources/SpotlightPlus/`) | What it does |
|---|---|
| `main.swift`, `AppDelegate.swift` | App startup, menu-bar icon, settings window |
| `Trigger.swift` | Double-tap-modifier trigger (global `NSEvent` monitor), `LegacyMigration` from bundle id `local.mike.StartMenu` |
| `ShortcutConflict.swift` | Detects who else uses the global shortcut (macOS shortcuts exactly, known launcher apps as a guess) and shows the explanation dialog; Carbon registration does NOT fail on clashes |
| `Onboarding.swift` | First-run welcome window (permissions + shortcut); reopen via menu bar → Setup Guide… |
| `Dialogs.swift` | `ModalWindow` (titled, closable, runs via `NSApp.runModal`), `TextPrompt`, `AppPicker`; replaces NSAlert/NSOpenPanel so dialogs have a close button |
| `Spaces.swift` | Private SkyLight calls, looked up with `dlsym`: which Space a window is on (hidden helper windows are on none), bringing a window forward, and `RemoteAX` (Accessibility elements for windows on other Spaces, found by scanning element ids; windows sit at ids in the thousands). OK because the app is unsandboxed and not on the App Store |
| `Windows.swift` | Permissions, window thumbnails (ScreenCaptureKit; needs macOS 14 for images), hover popup panel, jump to window via Accessibility |
| `HotKey.swift` | Global shortcut (Carbon `RegisterEventHotKey`), `Shortcut` model + persistence |
| `Panel.swift` | The centered floating `NSPanel` and its keyboard handling |
| `SpotlightPlusView.swift` | The UI: search bar, category grids, placeholder tiles, running apps, results list |
| `Clipboard.swift` | `ClipboardHistory` (in-memory, polls the pasteboard, skips concealed items) and `ShortcutsCatalog` (`/usr/bin/shortcuts list`/`run`) |
| `Calculator.swift` | Arithmetic typed in the search field (hand-written parser, not NSExpression, which throws on bad input); result card appears first |
| `Search.swift` | Spotlight-index search via `NSMetadataQuery` |
| `Model.swift` | Dock import, `CategoryStore` (categories, persisted as JSON), running apps, launching, Dock hiding |
| `SettingsView.swift` | Settings and the shortcut recorder |

Pop-ups must go through `PanelController.keepVisible` so the panel stays visible behind them.

Other top-level files: `Package.swift`, `build_app.sh`, `README.md`.

## Build

```
./build_app.sh      # release build + assembles "build/SpotlightPlus.app" (Info.plist, ad-hoc codesign)
swift build         # compile only (debug)
```

`build_app.sh` stamps the real SDK version into the binary (`-platform_version macos 13.0 <sdk>`); SwiftPM alone records SDK 13.0, which makes macOS draw the app in an older compatibility look (small traffic lights). Check with `otool -l ... | grep -A4 LC_BUILD_VERSION`.

Output is `build/SpotlightPlus.app`; `.build/` and `build/` are git-ignored. To work in Xcode, open `Package.swift`.
