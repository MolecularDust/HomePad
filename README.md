# SpotlightPlus for macOS

A Windows 11–style launcher: press a shortcut and a panel pops up in the middle of the screen with a
search bar on top (searching the same index Spotlight uses) and a grid of pinned apps below.

## Build and run

Requires macOS 13 or later and Xcode or the Command Line Tools (`xcode-select --install`).

```
chmod +x build_app.sh
./build_app.sh
```

This creates `build/SpotlightPlus.app`. Move it to **/Applications** and open it. Because it's signed
locally rather than by a registered developer, the first launch may need right-click → Open.

It runs as a menu-bar app (grid icon in the menu bar), with no Dock icon of its own.
To work on the code in Xcode instead, open `Package.swift` in Xcode and press Run.

## Using it

- **Option-Space** opens and closes the panel (change it in Settings), or double-tap Control, Option
  or Command (Settings → Shortcut; needs the Accessibility permission).
- **Categories**: apps live in named categories. **Essentials** comes first and is seeded from your Dock on
  first launch, plus a **Files** category with Downloads and the Trash, like the right end of the Dock. Add your own (Browsers, Writing…) with **Add Category** or by right-clicking empty space.
  A new category shows a grayed-out "Add your app here" tile. Right-click a category name to rename or delete
  it (its apps move to Essentials).
- **Add files and folders**: **Add File or Folder** (header link, right-click menu, or Settings), drag them in from Finder,
  or right-click a search result → Pin. They open when clicked; folders open in Finder. The picker is a browser
  window with a sidebar (Home, Desktop, Documents, Downloads, ..., drives) and a **Trash** entry that pins your Trash.
  Clicking a place in the sidebar (Documents, Downloads, Trash ...) opens it and picks the folder itself, so **Add** is
  ready. These windows don't block the panel: move one aside and drag any tile from it into the panel.
- **Add apps**: the Add App button (double-click an app in the picker to add it and close the picker), right-click empty space, drag apps in from Finder (press the shortcut
  mid-drag), or right-click a search result → Pin App.
- **Remove / reorder**: right-click a tile → Unpin App / Move Left / Move Right / Move to, or drag tiles
  around, including between categories.
- **Running apps**: a red bar under an icon means the app is running. Hover a running app to see a thumbnail
  of each of its windows, on every desktop (Space), listed in Mission Control order with a "Space N" title when an app has windows on more than one and click one to jump straight to it (switching desktops if needed), or click the cross in its corner to close just that window (also works for windows on other desktops) (needs Screen Recording and Accessibility;
  without Screen Recording you get a plain list). Clicking an app whose windows are all on other desktops takes you to one of them. Apps that are open but not in a category show in the
  **Running** section, which can't be edited (it can be turned off).
- **Running app menu**: right-click a running app for **Close Windows** (only if it has a window open; needs the Accessibility permission) and **Close App**.
- **Finding files**: files in Documents, Desktop and Downloads only appear in search once SpotlightPlus has
  **Full Disk Access** (System Settings → Privacy & Security). Until then, results show a notice with a link to the switch.
- **Calculator**: type a sum such as `7+3`, `(2+3)*4`, `2^10` or `15%` and the answer appears first. ↩ or the copy button copies it.
- **Search**: just start typing. Apps come first, then documents and folders, then a web search.
  ↑ ↓ to choose, ↩ to open, ⌘↩ to show in Finder, Esc to clear and then close. The ‹ button or a click on empty space also goes back to your apps.

## First run

A welcome window asks you to allow Screen Recording and Accessibility and to choose your shortcut. Reopen it
any time from the menu-bar icon → Setup Guide…

## Settings

- **Shortcut**: click the button and press a new combination. To use ⌘Space, first turn off
  Spotlight's shortcut in System Settings → Keyboard → Keyboard Shortcuts → Spotlight.
- **Shortcut**: record one, choose **None** if you only want the double-tap, or **Reset** it to ⌥Space.
- **Menu-bar icon**: Settings → General can hide it. Launching the app again opens the panel.
- **Reset to Defaults**: restores shortcut, double-tap, layout, Dock hiding and launch at login (apps and categories are kept).
- **Double-tap**: open with Control, Option or Command tapped twice.
- **Icons per row** (8 by default), **show running apps**, **re-import from Dock**.
- **Hide the Dock**: turns on Dock auto-hide with a 1000-second delay so it never appears.
  Turning it off restores the normal Dock.
- **Launch at login**.

## Files

| File | What it does |
|---|---|
| `main.swift`, `AppDelegate.swift` | App startup, menu-bar icon, settings window |
| `Trigger.swift` | Double-tap-modifier trigger, one-time migration from the old "Start Menu" settings |
| `Dialogs.swift` | Closable modal windows (new/rename category, Add App picker) shown above the panel |
| `Windows.swift` | Permissions, window listing and thumbnails (ScreenCaptureKit), hover popup, jump to window (Accessibility) |
| `HotKey.swift` | Global shortcut (Carbon `RegisterEventHotKey`, no permissions needed) |
| `Panel.swift` | The centered floating window and its keyboard handling |
| `SpotlightPlusView.swift` | The UI: search bar, category grids, running apps, results list |
| `Search.swift` | Spotlight-index search via `NSMetadataQuery` |
| `Model.swift` | Dock import, categories, running apps, launching, Dock hiding |
| `SettingsView.swift` | Settings and the shortcut recorder |
