# Localization in HomePad

HomePad is translated into **20 languages** (English plus 19), with a language choice inside the app, right-to-left
layout, a translation checker, and a translated installer. This page describes what exists and how it works, so it
can be reused in another project. For the user-facing description, see the Settings and Translations sections of
[README.md](README.md).

## What exists

| Part | Where | What it does |
|---|---|---|
| Languages | `Localization.codes` (`Sources/HomePad/Localization.swift`), `CODES` in `tools/localize.py`, `tools/pkg/text/` | Arabic (`ar`), Bengali (`bn`), Chinese Simplified (`zh-Hans`), English (`en`), Filipino/Tagalog (`fil`), French (`fr`), German (`de`), Hindi (`hi`), Indonesian (`id`), Italian (`it`), Japanese (`ja`), Korean (`ko`), Persian (`fa`), Portuguese Brazil (`pt-BR`), Russian (`ru`), Spanish (`es`), Telugu (`te`), Thai (`th`), Turkish (`tr`), Vietnamese (`vi`) |
| Language choice | Settings → General → Language, and the menu-bar icon's right-click menu → Language | "Same as the Mac" or any of the 20, listed alphabetically in the current language by macOS's own language names (`Localization.options`). Choosing restarts the app (`Localization.choose`, `Relaunch`), reopening Settings if it was open |
| Source of translations | `tools/translations/<code>.json` | One JSON file per language: `{ "English text": "translation" }`. **Edit these, never the generated files** |
| Generated files | `Resources/<code>.lproj/Localizable.strings`, `InfoPlist.strings`, `Resources/en.lproj/` | Written by `tools/localize.py write`; `build_app.sh` copies every `Resources/*.lproj` into the app |
| Checker | `tools/localize.py check` | Per language: texts with no translation, translations nobody uses, and translations whose placeholders or ⟦macOS names⟧ differ from the English. Exits non-zero on problems |
| Finder for texts | `tools/localize.py keys` | Prints every text the app can show, found by the compiler (`-emit-localized-strings`), as JSON `{text: "file:line"}` |
| Right to left | `Localization.choose` | Arabic and Persian lay out right to left, everywhere (windows, taskbar, Settings tab bar) |
| Visual check | `tools/snapshot.sh <code>` | Debug build draws each Settings tab, the panel and the Setup Guide to PNGs in `build/snapshots/<code>` with no screen permission, to check for cut-off text and RTL |
| Installer | `tools/pkg/text/<code>.json`, `tools/pkg/make_pages.py`, `tools/make_installer_dmg.sh [code\|all]` | The package installer's pages and the disk image's picture, in all 20 languages |

As of this writing the checker reports 305 texts and no problems in every language.

## How it works

### The English text is the key

There is no separate key list. A text written in the code, `Text("Show menu-bar icon")`, is its own key, and the
translation files map it to each language. The compiler finds every such text (`tools/localize.py keys`), so nothing
has to be registered by hand.

- **SwiftUI** `Text("…")`, `Button("…")`, `Toggle("…")`, `Picker("…")` literals follow the window's locale: every
  hosting view's root gets `.localized()`, which sets `\.locale` to the chosen language.
- **Strings** (AppKit menus, alerts, window titles, anything that isn't a SwiftUI literal) go through `L("…")`.
- **Values** are interpolated in whole sentences: `L("Battery: \(percent)%, charging")`, never glued pieces. A
  translation keeps the placeholders (`%lld`, `%@`) and may reorder them as `%1$@`, `%2$lld`. The checker verifies this.
- **Texts that are not translated** (numbers, names, symbols) use `Text(verbatim: …)`.
- **Info.plist texts** (permission descriptions) are listed in `INFO_PLIST` in `tools/localize.py` and written to
  `InfoPlist.strings`.

### Two languages: the chosen one and macOS's

The app's own text is in the chosen language, but **macOS's own names are never translated**: apps, folders, files,
System Settings and its sections, Mission Control, the Dock, the Trash. They appear exactly as the Mac shows them.

To make that work the app keeps running in the *Mac's* language (so macOS hands it app and folder names as the Mac
shows them) and only looks its own text up in the chosen language's `.lproj`:

- `Localization.bundle` is the chosen language's translations; `Localization.macBundle` is the translation folder for
  macOS's language (Finder's).
- A macOS name inside a sentence is written `⟦Trash⟧` in the English key **and in every translation**. `L()` swaps it
  for the name in macOS's language. Used alone, the name is `Mac("Trash")`.
- Each ⟦name⟧ is a text of its own in the translation files, translated *as macOS shows it in that language* (for
  example `"Dock"`, `"Accessibility": "Bedienungshilfen"` in German). The checker adds these automatically.
- Layout direction is not taken from the app's choice by AppKit, so it is forced with the `AppleTextDirection` and
  `NSForceRightToLeftWritingDirection` defaults when a language is chosen.

Result: an English Mac with HomePad set to Russian shows Russian text around English macOS names, and a Russian Mac
shows "Системные настройки" for System Settings whatever HomePad's language is.

### Installer

The package installer (`.pkg`) and the disk image around it are translated separately, because Installer shows its
pages in the Mac's language, not the app's:

- All installer text is in `tools/pkg/text/<code>.json` (`en.json` is the English).
- `tools/pkg/make_pages.py <out-dir>` writes `<code>.lproj/{welcome,readme,conclusion}.html`. **No top-level pages**:
  Installer prefers a top-level page over the Mac's language and would always show it. Right-to-left lists have their
  numbers written in, since Installer puts list numbers on the left. `--check` compares each language with English.
- `tools/make_installer_dmg.sh all` builds a disk image per language (`dist/<code>/HomePad-Installer.dmg`), with the
  window picture laid out from the measured text (mirrored for Arabic and Persian).
- macOS's own buttons and names there use the official ones for the language; for Bengali, Telugu, Filipino and
  Persian, which macOS isn't available in, they stay English.

## Doing it again in another project

1. **Declare the languages**: a list of `.lproj` codes, `CFBundleDevelopmentRegion` = `en`, and copy `Resources/*.lproj`
   into the app bundle (see `build_app.sh`).
2. **Copy `tools/localize.py`**: change `CODES`, `ROOT`, `INFO_PLIST`, and the build command in `keys()` if the target
   isn't a Swift package (any Swift build that accepts `-Xswiftc -emit-localized-strings` works).
3. **Copy `Localization.swift`** (language list, `chosen`, `current`, `bundle`, `macBundle`, `choose`, `options`, `L`,
   `Mac`, `.localized()`) and call `.localized()` on every hosting view's root.
4. **Write `tools/translations/<code>.json`** for each language, then `tools/localize.py write` and `check`.
5. **Add the picker**: a Picker over `Localization.options` in Settings, and `Localization.menu()` in a menu-bar menu.
6. **Skip ⟦macOS names⟧** if the app doesn't show macOS names; the rest works without them.

## Adding a language to HomePad

1. Add its code to `Localization.codes`, `CODES` in `tools/localize.py`, and `RTL` in `tools/pkg/make_pages.py` if it
   is right to left.
2. Create `tools/translations/<code>.json` with every text (copy another language's file as the template).
3. Create `tools/pkg/text/<code>.json` from `en.json` for the installer.
4. Run `tools/localize.py write`, `tools/localize.py check` and `tools/pkg/make_pages.py --check`.
5. Run `tools/snapshot.sh <code>` and look at every picture.

## Gotchas learned the hard way

- **Translated text is longer.** Captions need `.fixedSize(horizontal: false, vertical: true)`, and rows of buttons must
  be able to wrap (`ViewThatFits`). Check with the longest languages (Russian, German) and Arabic.
- **A macOS name in a SwiftUI literal shows the raw `⟦ ⟧` marks** unless it goes through `L()`: write `Text(L("…"))`.
- **Don't translate what macOS names.** An early version translated app, folder and file names itself, which showed
  Russian names on an English Mac; the rule since is `⟦Name⟧` or `Mac("Name")`.
- **Do not force the app's language with `AppleLanguages`.** It makes macOS hand over folder and app names in that
  language. Keep the app in the Mac's language and look its own text up separately (`Localization.migrate()` moves an
  old `AppleLanguages` choice to the new setting).
- **Quoting varies by language.** The marks around a macOS name follow each language's own quotes (« », „ “, “ ”, ‘ ’).
- **Translations were written by an AI and not reviewed by native speakers.** Have each language reviewed before relying
  on it.
