import Foundation

/// App-level language override. The default is to follow macOS; the Settings
/// screen can force one of the supported localizations for the next launch.
public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"

    public var id: String { rawValue }

    public var localizationCode: String? {
        switch self {
        case .system: return nil
        case .english, .simplifiedChinese, .traditionalChinese, .japanese:
            return rawValue
        }
    }

    public var displayName: String {
        switch self {
        case .system: return L("跟随系统")
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .japanese: return "日本語"
        }
    }
}

public enum LanguagePreference {
    public static let defaultsKey = "switchpilot.language"

    public static var selected: AppLanguage {
        guard let raw = UserDefaults.standard.string(forKey: defaultsKey),
              let value = AppLanguage(rawValue: raw) else {
            return .system
        }
        return value
    }

    public static func set(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: defaultsKey)
    }

    /// Apply the saved language before AppKit/SwiftUI resolve localized
    /// resources. The AppleLanguages key is scoped to this app's defaults, not
    /// the system-wide preference domain.
    public static func applyAtLaunch() {
        let forced = ProcessInfo.processInfo.environment["SWITCHPILOT_LANGUAGE"]
        let language: AppLanguage
        if let forced, let parsed = AppLanguage(rawValue: forced) {
            language = parsed
        } else if forced == "zh" {
            language = .simplifiedChinese
        } else {
            language = selected
        }

        if let code = language.localizationCode {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }
}

/// Lightweight localization helper. Source strings are Chinese and every
/// supported locale supplies a `.lproj/Localizable.strings` table.
public enum AppLocalization {
    public static var activeCode: String? {
        if let forced = ProcessInfo.processInfo.environment["SWITCHPILOT_LANGUAGE"] {
            if forced == "zh" { return AppLanguage.simplifiedChinese.rawValue }
            if let parsed = AppLanguage(rawValue: forced), parsed != .system {
                return parsed.localizationCode
            }
        }
        return LanguagePreference.selected.localizationCode
    }

    public static func bundle(for code: String) -> Bundle? {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj") else { return nil }
        return Bundle(path: path)
    }

    public static func string(_ key: String) -> String {
        if let code = activeCode, let bundle = bundle(for: code) {
            return bundle.localizedString(forKey: key, value: key, table: nil)
        }
        return NSLocalizedString(key, comment: "")
    }
}

/// Localize a source string. The Chinese source string is the fallback key.
public func L(_ key: String) -> String {
    AppLocalization.string(key)
}

/// Localize a format string and interpolate values.
public func LF(_ format: String, _ arguments: CVarArg...) -> String {
    String(format: AppLocalization.string(format), arguments: arguments)
}
