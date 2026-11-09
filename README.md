# HomePad for macOS

A Windows 11–style launcher: press a shortcut and a panel pops up in the middle of the screen with a
search bar on top (searching the same index Spotlight uses) and a grid of pinned apps below.

## Build and run

Requires macOS 13 or later and Xcode or the Command Line Tools (`xcode-select --install`).

```
chmod +x build_app.sh
./build_app.sh
```

This creates `build/HomePad.app`. Move it to **/Applications** and open it. Because it's signed
locally rather than by a registered developer, the first launch may need right-click → Open.

It runs as a menu-bar app (grid icon in the menu bar), with no Dock icon of its own. Click the icon to open or close the panel; right-click (or Control-click) it for Settings, the Setup Guide, Uninstall HomePad… and Quit. Uninstalling brings the Dock back if HomePad hid it, takes back its permissions, erases its settings and categories, moves the app to the Trash and forgets the installer's record (asking for an administrator password only when the installer put the app there). The same steps are in `Resources/uninstall.sh`, which also runs on its own (`bash Resources/uninstall.sh --dry-run` shows what it would do).

**Sharing it with friends:** `tools/make_release.sh` makes `dist/HomePad.zip` (for Apple silicon and Intel Macs)
with [INSTALL.md](INSTALL.md) inside as "How to install HomePad.txt", a step-by-step guide for getting past macOS's
block on apps that aren't registered with Apple, and through the Setup Guide. `tools/make_dmg.sh` makes
`dist/HomePad.dmg` instead: a disk image with the app, a shortcut to Applications to drag it onto, and the same guide
as "READ ME FIRST - How to install HomePad.txt". `tools/make_pkg.sh` makes `dist/HomePad.pkg`, an installer wizard
(Welcome, What to expect, Install, Done) that puts the app in Applications and opens it, so nothing has to be read or
dragged. It isn't signed, so macOS blocks the package once (System Settings → Privacy & Security → Open Anyway); an app
installed by Installer is not marked "downloaded from the internet", so HomePad itself opens without a block.
`tools/make_installer_dmg.sh` wraps that package in `dist/HomePad-Installer.dmg` (or `tools/make_installer_dmg.sh ru` for a Russian one in `dist/ru/`, `all` for every language), whose window shows the Open Anyway
steps as a picture beside the installer, so they are on screen before the block (opening a disk image isn't blocked; a
script would be). This is the one to send.
To work on the code in Xcode instead, open `Package.swift` in Xcode and press Run.

## Using it

- **Option-Space** opens and closes the panel (change it in Settings), or double-tap Control, Option
  or Command (Settings → Shortcut; needs the Accessibility permission).
- **Hot corners**: Settings → Shortcut → hot corners. Click any of the four corners of the little screen (one, several or
  all). Rest the pointer in a chosen corner for a moment and the panel opens in that corner; do it again to close it.
  A quick brush past the corner, or a drag with the mouse button held, does nothing. The shortcut and double-tap
  still open it in the middle. Also in the Setup Guide's second step. If macOS uses the same corner for one of its
  own actions, HomePad says so, with an **Open macOS Hot Corners…** button that opens System Settings → Desktop & Dock
  with its Hot Corners sheet already showing (pressing that button needs Accessibility; without it, the page).
- **Categories**: apps live in named categories. **Essentials** comes first and is seeded from your Dock on
  first launch, plus a **Files** category with the Trash and Downloads, like the right end of the Dock (only on the very first run; if you delete it, it stays deleted). Add your own (Browsers, Writing…) with **Add Category** or by right-clicking empty space.
  A new category shows a grayed-out "Add your app here" tile. Right-click inside a category to rename or delete
  it (everything in it is unpinned too; the apps and files themselves are untouched).
- **Add files and folders**: **Add File or Folder** (header link, right-click menu, or Settings), drag them in from Finder,
  or right-click a search result → Pin. They open when clicked; folders open in Finder. The picker is a browser
  window with a sidebar (Home, Desktop, Documents, Downloads, ..., drives) and a **Trash** entry that pins your Trash.
  Clicking a place in the sidebar (Documents, Downloads, Trash ...) opens it and picks the folder itself, so **Add** is
  ready. These windows don't block the panel: move one aside and drag any tile from it into the panel. Right-click the Trash tile for **Empty Trash…** (it asks first; HomePad has Finder empty it, as the Dock does, so the first time macOS asks whether HomePad may control Finder).
- **Category order**: a category's name turns green when you point at it. Press it and the whole row is selected
  (green fill and outline); drag and the row itself comes along while the other rows slide aside to make
  room (the panel stays where it is). Let go and it stays where it is. Or right-click inside a category and choose **Move Up** /
  **Move Down**. While something is being dragged, hover effects and window previews stay off. Essentials can be
  moved too; it stays the default place for new items and can't be deleted. Thin gray lines separate the categories.
- **Right-click to add**: right-click empty space inside a category (its title, or the gaps between and after its
  tiles) and the menu adds to *that* category: "Add App to Files…", "Add File or Folder to Files…", plus Add Category,
  Rename and Delete for it, and **Sort Alphabetically** (puts that category's tiles in alphabetical order by the names they
  show; grayed out when they already are; the tiles inside its folders keep theirs). The blank space below the last section
  belongs to that section.
- **Add apps**: the Add App button (double-click an app in the picker to add it and close the picker), right-click empty space, drag apps in from Finder (press the shortcut
  mid-drag), or right-click a search result → Pin App.
- **Folders** (as in the Windows Start menu): drag a tile onto the middle of another tile's icon, hold it there for
  half a second until that icon lights up, and let go: the two become a folder in that place, named "Folder", whose tile shows its first four items. Drop more
  tiles on a folder to add them. Click a folder to open it over the panel: click its name to rename it, click an item
  to open it, drag items to rearrange them or out of the folder (it closes so you can drop the item among the other
  tiles). Esc or a click outside closes it. A folder left with one item turns back into that item. Right-click a
  folder for Rename Folder…, Move to and Ungroup; right-click an item in an open folder for Remove from Folder.
  Dragging over a tile's edges (not its middle) still just reorders.
- **Remove / reorder**: right-click a tile → Unpin App / Move to, or drag tiles
  around, including between categories.
- **Running apps**: a red bar right under an icon (above its name) means the app is running. Hover a running app to see a thumbnail
  of each of its windows (a minimized one has a minus beside its close cross), on every desktop (Space), listed in Mission Control order with a "Space N" title when an app has windows on more than one and click one to jump straight to it (switching desktops if needed), or click the cross in its corner to close just that window (also works for windows on other desktops) (needs Screen Recording and Accessibility;
  without Screen Recording you get a plain list). Clicking a running app puts the current desktop first: a window showing there brings the app forward; if its windows there are all minimised, the most recent one comes back; only with no window there at all does it take you to another desktop where it has windows. The **Running** section lists every app that is running (pinned or not, like the Dock's running indicators); nothing can be added to or removed from it, but its tiles can be **dragged around within it to reorder them** (alphabetical until you move one; the order is remembered, also for an app that quits and starts again; a tile can't be dropped anywhere else, and Esc or letting go elsewhere puts it back; right-click Running → **Sort Alphabetically** forgets your order), and the section itself can't be renamed but can be dragged by its title (or moved with **Move Up** / **Move Down** in its right-click menu) to any place among the categories, and it can be hidden (right-click it → Hide Running; bring it back with Settings → Layout → Show the Running section). Each running app's **minimized windows** can follow its tile there, as tiles of their own: a picture of the window with the app's icon in the corner and the window's title (as the Dock shows them). Click one to bring that window back; right-click for Restore or Close Window. They're off by default: turn on Settings → Layout → Show minimized windows in Running, or right-click Running → Show Minimized Windows. They're gathered each time the panel opens (needs Accessibility; the pictures need Screen Recording).
- **Running app menu**: right-click a running app for a menu like the Dock's: its windows (the one in front checked; choose one to bring it forward), the "New …" commands from its File menu (New Tab, New Window, New Private Window in a browser), then **Close Windows** (only if it has a window open), **Hide** and **Quit** (hold Option to force quit; an app still running a few seconds after Quit gets **Force Quit** in its place; Finder has no Quit, as in the Dock, since quitting it removes the desktop icons). Windows and commands are read through Accessibility when the pointer reaches the tile.
- **Finding files**: files in Documents, Desktop and Downloads only appear in search once HomePad has
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
- **Mode** (top of Settings):
  - **Standalone** (default): the floating panel, opened by the shortcut, double-tap, hot corners or the menu-bar icon.
    Switching to it hides the Dock; **Hide the Dock** below brings it back.
  - **HomePad + Dock**: a Windows Start-menu workflow with the Dock as the taskbar. Choosing it always shows the Dock (it
    turns off auto-hide, HomePad's or System Settings') and adds HomePad to it if it isn't there (the Dock restarts once); the Dock stays wherever you put it.
    The panel opens right by HomePad's icon (above it for a bottom Dock, beside it for a side Dock, kept on screen)
    whether you click the icon or use the shortcut or double-tap; clicking the icon again closes it. Hot corners still
    open it in their corner. Settings says why it falls back to the middle when HomePad isn't in the Dock, the Dock is
    hidden, or the Accessibility permission is missing.
  - **Taskbar**: a Windows 11–style taskbar along the bottom of the main screen: a Start button (HomePad's icon),
    then what you pinned to it and the running apps, centred. The running apps then leave the panel. Pin apps, files
    and folders by right-clicking the taskbar's blank space (**Add App…**, **Add File or Folder…**) or a tile
    (**Pin to Taskbar**; in HomePad's panel too). The taskbar's pins are a list of their own, apart from HomePad's
    categories. Drag icons along the taskbar to reorder them. Click an item to open it or bring it forward (or hide
    it if it's already in front); point at a running app for its windows; right-click for its menu. The
    panel opens centred above the taskbar. macOS lets only the Dock keep windows off part of the screen, so the Dock
    stays at the bottom, as tall as the taskbar, under it: maximized windows end at the taskbar's top. Its size,
    magnification and side are put back when you leave the mode. **Open HomePad only from the Start button** turns off the shortcut, double-tap and hot corners
    (the menu-bar icon still works).
- **Hide the Dock** (Standalone only): turns on Dock auto-hide with a 1000-second delay so it never appears.
  Turning it off restores the normal Dock.
- **Launch at login**.
- **Language** (Settings → General, or right-click the menu-bar icon → Language): Same as the Mac, or one of 20
  languages (Arabic, Bengali, Chinese (Simplified), English, Filipino, French, German, Hindi, Indonesian, Italian,
  Japanese, Korean, Persian, Portuguese (Brazil), Russian, Spanish, Telugu, Thai, Turkish, Vietnamese), listed
  alphabetically in the current language. HomePad restarts in the new one; Arabic and Persian lay out right to left.
  Names of apps, folders and System Settings sections stay as the Mac shows them.

## Translations

The English in the code is the text to translate; `tools/translations/<code>.json` holds each language and
`tools/localize.py write` turns them into `Resources/<code>.lproj` (which `build_app.sh` copies into the app). Names
macOS uses (apps, folders, System Settings and its sections…) are never translated: they're written `⟦Trash⟧` and
appear as the Mac shows them, in the Mac's own language, whatever language HomePad is set to. After
changing or adding text in the code, run `tools/localize.py check`: it lists every text without a translation, and
translations whose `%@` placeholders don't match. `tools/snapshot.sh <code>` saves pictures of Settings, the panel and
the Setup Guide in that language to `build/snapshots/<code>`, to check that nothing is cut off.

## Files

| File | What it does |
|---|---|
| `main.swift`, `AppDelegate.swift` | App startup, menu-bar icon, settings window |
| `Trigger.swift` | Double-tap-modifier trigger, one-time migration from the old "Start Menu" settings |
| `Dialogs.swift` | Closable modal windows (new/rename category, Add App picker) shown above the panel |
| `Windows.swift` | Permissions, window listing and thumbnails (ScreenCaptureKit), hover popup, jump to window (Accessibility) |
| `HotKey.swift` | Global shortcut (Carbon `RegisterEventHotKey`, no permissions needed) |
| `Panel.swift` | The centered floating window and its keyboard handling |
| `HomePadView.swift` | The UI: search bar, category grids, running apps, results list |
| `Search.swift` | Spotlight-index search via `NSMetadataQuery` |
| `Model.swift` | Dock import, categories, running apps, launching, Dock hiding |
| `SettingsView.swift` | Settings and the shortcut recorder |
| `Localization.swift` | The language list and choice (Settings and the menu-bar menu) |

## Setting up permissions

When you allow a permission (in the Setup Guide, Settings or a window preview), HomePad watches for it to be switched
on in System Settings and comes back to the front as soon as it is. Screen Recording and Full Disk Access usually need
a restart: when System Settings offers **Quit & Reopen**, HomePad quits, starts again on its own and reopens the window
you were in.

The Setup Guide shows on first launch only if a permission is missing. To go through it again from scratch, use
**Settings → Reset → Start Over…**: macOS takes back HomePad's permissions, the guide shows again and HomePad restarts
(tick the box to also forget your categories and settings, as on a fresh install).

## App icon

The icon is `Resources/AppIcon.svg`. After changing it, run `./tools/make_icon.sh` to rebuild `Resources/AppIcon.icns`
(all the sizes macOS uses, with a transparent background), then `./build_app.sh`.
