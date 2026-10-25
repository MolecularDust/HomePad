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
  first launch, plus a **Files** category with the Trash and Downloads, like the right end of the Dock (only on the very first run; if you delete it, it stays deleted). Add your own (Browsers, Writing…) with **Add Category** or by right-clicking empty space.
  A new category shows a grayed-out "Add your app here" tile. Right-click inside a category to rename or delete
  it (everything in it is unpinned too; the apps and files themselves are untouched).
- **Add files and folders**: **Add File or Folder** (header link, right-click menu, or Settings), drag them in from Finder,
  or right-click a search result → Pin. They open when clicked; folders open in Finder. The picker is a browser
  window with a sidebar (Home, Desktop, Documents, Downloads, ..., drives) and a **Trash** entry that pins your Trash.
  Clicking a place in the sidebar (Documents, Downloads, Trash ...) opens it and picks the folder itself, so **Add** is
  ready. These windows don't block the panel: move one aside and drag any tile from it into the panel.
- **Category order**: a category's name turns green when you point at it. Press it and the whole row is selected
  (green fill and outline); drag and the row itself comes along while the other rows slide aside to make
  room (the panel stays where it is). Let go and it stays where it is. Or right-click inside a category and choose **Move Up** /
  **Move Down**. While something is being dragged, hover effects and window previews stay off. Essentials can be
  moved too; it stays the default place for new items and can't be deleted. Thin gray lines separate the categories.
- **Right-click to add**: right-click empty space inside a category (its title, or the gaps between and after its
  tiles) and the menu adds to *that* category: "Add App to Files…", "Add File or Folder to Files…", plus Add Category,
  Rename and Delete for it. Right-click outside every category (below the last one) and it adds to Essentials.
- **Add apps**: the Add App button (double-click an app in the picker to add it and close the picker), right-click empty space, drag apps in from Finder (press the shortcut
  mid-drag), or right-click a search result → Pin App.
- **Remove / reorder**: right-click a tile → Unpin App / Move Left / Move Right / Move to, or drag tiles
  around, including between categories.
- **Running apps**: a red bar under an icon means the app is running. Hover a running app to see a thumbnail
  of each of its windows, on every desktop (Space), listed in Mission Control order with a "Space N" title when an app has windows on more than one and click one to jump straight to it (switching desktops if needed), or click the cross in its corner to close just that window (also works for windows on other desktops) (needs Screen Recording and Accessibility;
  without Screen Recording you get a plain list). Clicking an app whose windows are all on other desktops takes you to one of them. The **Running** section lists every app that is running (pinned or not, like the Dock's running indicators); nothing can be added to, renamed or removed from it, but it can be dragged by its title (or moved with **Move Up** / **Move Down** in its right-click menu) to any place among the categories, and it can be turned off in Settings.
- **Running app menu**: right-click a running app for **Close Windows** (only if it has a window open; needs the Accessibility permission) and **Close App**.
- **Finding files**: files in Documents, Desktop and Downloads only appear in search once SpotlightPlus has
  **Full Disk Access** (System Settings → Privacy & Security). Until then, results show a notice with a link to the switch.
- **Calculator**: type a sum such as `7+3`, `(2+3)*4`, `2^10` or `15%` and the answer appears first. ↩ or the copy button copies it.
- **Window**: drag any edge or corner of the panel to resize it (the edges have wide grab strips and show resize
  cursors), or drag any empty part to move it (not the tile grid itself, where dragging rearranges tiles). The search field has the focus whenever the panel opens, so you can type at once; after you click elsewhere, the next key you type goes back into it. Settings → Window has **Remember window size** (on by default) and
  **Remember window position** (off by default). The ↺ button beside the settings cogwheel puts the panel back to the
  standard size, centred. The Add App and Add File or Folder windows can be resized too (they always open at their
  standard size).
- **Your name** in the panel's lower-left corner opens System Settings on your Apple Account.
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
- **Icons per row** (8 by default, 4–10) and **row height** (the distance between rows of icons, 101 pt by default,
  85–125) and **icon spacing** (the horizontal gap between icons, 10 pt by default, 0–40; when the panel is
  too narrow for the gap, the gap shrinks first, then the icons): type a number or click − / +, **show running apps**, **re-import from Dock**.
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
