import AppKit

/// HomePad's languages and the choice between them (Settings → General, and the menu-bar icon's right-click menu).
///
/// Text is looked up the standard way (SwiftUI `Text("…")`, `String(localized:)`) in
/// `Resources/<code>.lproj/Localizable.strings`, which `build_app.sh` copies into the app. A chosen language is stored
/// as `AppleLanguages` in HomePad's own settings only, and HomePad restarts: macOS picks an app's language at launch.
enum Localization {
    /// The `.lproj` folder names. English is the text in the code itself.
    static let codes = ["en", "ar", "bn", "de", "es", "fa", "fil", "fr", "hi", "id", "it", "ja", "ko", "pt-BR", "ru", "te", "th", "tr", "vi", "zh-Hans"]
    private static let key = "AppleLanguages"

    /// The language picked in HomePad, or nil when it follows the Mac.
    static var chosen: String? {
        guard let id = Bundle.main.bundleIdentifier,
              let first = (UserDefaults.standard.persistentDomain(forName: id)?[key] as? [String])?.first else { return nil }
        return codes.first { first == $0 || first.hasPrefix($0 + "-") } ?? first
    }

    /// The language HomePad is showing now.
    static var current: String { Bundle.main.preferredLocalizations.first ?? "en" }

    /// Stores the choice (nil: same as the Mac) and restarts HomePad in it, reopening Settings if it was open.
    static func choose(_ code: String?) {
        guard code != chosen else { return }
        let d = UserDefaults.standard
        if let code {
            d.set([code], forKey: key)
            // macOS takes the reading direction from the Mac's language, not an app's own choice, so it is set too:
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
        let here = Locale(identifier: current)
        return codes.map { code in
            let local = capitalized(here.localizedString(forIdentifier: code) ?? code, here)
            let own = capitalized(Locale(identifier: code).localizedString(forIdentifier: code) ?? code, Locale(identifier: code))
            return (code, local == own ? local : "\(local) — \(own)")
        }
        .sorted { $0.title.compare($1.title, options: [.caseInsensitive], locale: here) == .orderedAscending }
    }

    private static func capitalized(_ s: String, _ locale: Locale) -> String {
        guard let first = s.first else { return s }
        return String(first).uppercased(with: locale) + s.dropFirst()
    }

    /// A text's translations in every language, e.g. to tell whether a saved name is still a default one.
    static func defaultNames(for text: String) -> Set<String> {
        var names: Set<String> = [text]
        for code in codes {
            if let path = Bundle.main.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) {
                names.insert(bundle.localizedString(forKey: text, value: text, table: nil))
            }
        }
        return names
    }

    /// The Language submenu for the menu-bar icon: Same as the Mac, then every language, a tick on the current choice.
    static func menu() -> NSMenu {
        let menu = NSMenu()
        let system = NSMenuItem(title: String(localized: "Same as the Mac"), action: #selector(MenuTarget.pick(_:)), keyEquivalent: "")
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
