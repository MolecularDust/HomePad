import AppKit
import SwiftUI

/// HomePad's languages and the choice between them (Settings → General, and the menu-bar icon's right-click menu).
///
/// Two languages are in play. HomePad's own text is in the chosen one (or the Mac's, by default). Everything macOS
/// names (apps, folders, files, System Settings and its sections, Mission Control, the Trash…) stays exactly as the
/// Mac shows it, in macOS's own language. That is why HomePad itself keeps running in the Mac's language (so macOS hands
/// it app and folder names in that language) and only looks its own text up in the chosen one:
///
/// - SwiftUI windows get the chosen language as their locale (`.localized()`), which `Text("…")` and friends follow.
/// - Text passed as a String goes through `L("…")`, looked up in the chosen language's `.lproj`.
/// - A macOS name inside a text is written `⟦Trash⟧` (in English, in every translation); `L` swaps it for `Mac("Trash")`:
///   the name in macOS's language, which is Finder's language, from the same translation files. Used alone, a macOS
///   name is `Mac("…")`.
///
/// Translations: `Resources/<code>.lproj/Localizable.strings`, written by tools/localize.py from tools/translations.
enum Localization {
    /// The `.lproj` folder names. English is the text in the code itself.
    static let codes = ["en", "ar", "bn", "de", "es", "fa", "fil", "fr", "hi", "id", "it", "ja", "ko", "pt-BR", "ru", "te", "th", "tr", "vi", "zh-Hans"]
    private static let key = "language"

    /// The language picked in HomePad, or nil when it follows the Mac.
    static var chosen: String? { UserDefaults.standard.string(forKey: key).flatMap(match) }

    /// The language HomePad's own text is in.
    static let current: String = chosen ?? Bundle.main.preferredLocalizations.first ?? "en"
    static let locale = Locale(identifier: current)
    static let bundle: Bundle = folder(current) ?? .main

    /// macOS's own language (Finder's), and the translation folder for its names. English when HomePad has none for it.
    static let macBundle: Bundle = {
        let finder = Bundle(path: "/System/Library/CoreServices/Finder.app")?.preferredLocalizations.first ?? "en"
        return match(finder.replacingOccurrences(of: "_", with: "-")).flatMap(folder) ?? folder("en") ?? .main
    }()

    private static func folder(_ code: String) -> Bundle? {
        Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:))
    }

    /// One of `codes` for a language name such as "ru", "pt-BR", "zh-Hans" or "zh-CN".
    private static func match(_ name: String) -> String? {
        if codes.contains(name) { return name }
        let lower = name.lowercased()
        if lower.hasPrefix("zh") { return lower.contains("hant") || lower.contains("tw") || lower.contains("hk") ? nil : "zh-Hans" }
        if lower.hasPrefix("pt") { return "pt-BR" }
        if lower.hasPrefix("tl") { return "fil" }
        return codes.first { lower.hasPrefix($0.lowercased() + "-") || lower == $0.lowercased() }
    }

    /// HomePad's old way (before 1.0 shipped): the language was forced on the whole app. Moved to its own setting.
    static func migrate() {
        let d = UserDefaults.standard
        guard let id = Bundle.main.bundleIdentifier,
              let old = (d.persistentDomain(forName: id)?["AppleLanguages"] as? [String])?.first else { return }
        d.removeObject(forKey: "AppleLanguages")
        if d.string(forKey: key) == nil { d.set(old, forKey: key) }
    }

    /// Stores the choice (nil: same as the Mac) and restarts HomePad in it, reopening Settings if it was open.
    static func choose(_ code: String?) {
        guard code != chosen else { return }
        let d = UserDefaults.standard
        if let code {
            d.set(code, forKey: key)
            // AppKit takes the layout direction from the Mac's language, not an app's own choice, so it is set too:
            // right to left for Arabic and Persian, left to right otherwise (an English HomePad on an Arabic Mac).
            d.set(true, forKey: "AppleTextDirection")
            d.set(Locale.Language(identifier: code).characterDirection == .rightToLeft, forKey: "NSForceRightToLeftWritingDirection")
        } else {
            for k in [key, "AppleTextDirection", "NSForceRightToLeftWritingDirection"] { d.removeObject(forKey: k) }
        }
        Relaunch.afterQuitting(reopening: AppDelegate.shared?.settingsWindowIsOpen == true ? "settings" : nil)
        NSApp.terminate(nil)
    }

    /// Every language as "its name in the current language — its own name", in the current language's alphabetical
    /// order. macOS supplies both names, so the list needs no translating.
    static var options: [(code: String, title: String)] {
        codes.map { code in
            let local = capitalized(locale.localizedString(forIdentifier: code) ?? code, locale)
            let own = capitalized(Locale(identifier: code).localizedString(forIdentifier: code) ?? code, Locale(identifier: code))
            return (code, local == own ? local : "\(local) — \(own)")
        }
        .sorted { $0.title.compare($1.title, options: [.caseInsensitive], locale: locale) == .orderedAscending }
    }

    private static func capitalized(_ s: String, _ locale: Locale) -> String {
        guard let first = s.first else { return s }
        return String(first).uppercased(with: locale) + s.dropFirst()
    }

    /// A text's translations in every language, e.g. to tell whether a saved name is still a default one.
    static func defaultNames(for text: String) -> Set<String> {
        var names: Set<String> = [text]
        for code in codes {
            if let bundle = folder(code) { names.insert(bundle.localizedString(forKey: text, value: text, table: nil)) }
        }
        return names
    }

    /// Swaps every ⟦macOS name⟧ for that name in macOS's language.
    static func fillMacNames(_ s: String) -> String {
        guard s.contains("⟦") else { return s }
        var out = "", rest = Substring(s)
        while let open = rest.range(of: "⟦"), let close = rest.range(of: "⟧", range: open.upperBound..<rest.endIndex) {
            out += rest[..<open.lowerBound]
            let name = String(rest[open.upperBound..<close.lowerBound])
            out += macBundle.localizedString(forKey: name, value: name, table: nil)
            rest = rest[close.upperBound...]
        }
        return out + rest
    }

    /// The Language submenu for the menu-bar icon: Same as the Mac, then every language, a tick on the current choice.
    static func menu() -> NSMenu {
        let menu = NSMenu()
        let system = NSMenuItem(title: L("Same as the Mac"), action: #selector(MenuTarget.pick(_:)), keyEquivalent: "")
        system.target = MenuTarget.shared
        system.state = chosen == nil ? .on : .off
        menu.addItem(system)
        menu.addItem(.separator())
        for option in options {
            let item = NSMenuItem(title: option.title, action: #selector(MenuTarget.pick(_:)), keyEquivalent: "")
            item.target = MenuTarget.shared
            item.representedObject = option.code
            item.state = chosen == option.code ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    private final class MenuTarget: NSObject {
        static let shared = MenuTarget()
        @objc func pick(_ sender: NSMenuItem) { Localization.choose(sender.representedObject as? String) }
    }
}

/// HomePad's own text in the chosen language, with ⟦macOS names⟧ in macOS's language.
func L(_ text: String.LocalizationValue) -> String {
    Localization.fillMacNames(String(localized: text, bundle: Localization.bundle))
}

/// A name macOS uses (an app, folder, System Settings section, Mission Control…), as the Mac shows it.
func Mac(_ name: String.LocalizationValue) -> String {
    String(localized: name, bundle: Localization.macBundle)
}

extension View {
    /// The chosen language for a SwiftUI window's own text (`Text("…")`, `Button("…")`…).
    func localized() -> some View { environment(\.locale, Localization.locale) }
}
