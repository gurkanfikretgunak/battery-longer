import Foundation
import Combine

/// Supported UI languages. `.system` follows the user's macOS preference and falls back to English.
enum Language: String, CaseIterable, Identifiable {
    case system, en, tr, fr, ja, de

    var id: String { rawValue }

    /// Native display name for pickers.
    var nativeName: String {
        switch self {
        case .system: return L("lang.system")
        case .en: return "English"
        case .tr: return "Türkçe"
        case .fr: return "Français"
        case .ja: return "日本語"
        case .de: return "Deutsch"
        }
    }

    static func fromSystem() -> Language {
        for id in Locale.preferredLanguages {
            let code = id.split(separator: "-").first.map(String.init)?.lowercased() ?? ""
            if let match = Language(rawValue: code), match != .system { return match }
        }
        return .en
    }
}

/// Runtime-switchable string table. Views observe `Localization.shared` and re-render on change.
final class Localization: ObservableObject {
    static let shared = Localization()

    private static let key = "language"

    @Published var language: Language {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.key)
            resolved = language == .system ? Language.fromSystem() : language
        }
    }

    @Published private(set) var resolved: Language

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.key).flatMap(Language.init(rawValue:)) ?? .system
        language = stored
        resolved = stored == .system ? Language.fromSystem() : stored
    }

    fileprivate func string(_ key: String) -> String {
        if let s = Self.tables[resolved]?[key] { return s }
        if let s = Self.tables[.en]?[key] { return s }
        return key
    }

    private static let tables: [Language: [String: String]] = [
        .en: Strings.en,
        .tr: Strings.tr,
        .fr: Strings.fr,
        .ja: Strings.ja,
        .de: Strings.de,
    ]

    var locale: Locale {
        Locale(identifier: resolved.rawValue)
    }
}

/// Look up a localized string, optionally formatting it (`%d`, `%@`, `%1$@` …).
func L(_ key: String, _ args: CVarArg...) -> String {
    let template = Localization.shared.string(key)
    guard !args.isEmpty else { return template.replacingOccurrences(of: "%%", with: "%") }
    return String(format: template, locale: Localization.shared.locale, arguments: args)
}
