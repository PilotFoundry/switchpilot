import Foundation

/// Lightweight localization helper.
///
/// The source strings are Chinese; `Resources/en.lproj/Localizable.strings`
/// provides English. On an English system macOS resolves the English table; on
/// a Chinese system the source string is the fallback. A forced language can be
/// selected for screenshots and tests with `SWITCHPILOT_LANGUAGE=en|zh`.
public enum AppLocalization {
    public static let forcedLanguage: String? = {
        ProcessInfo.processInfo.environment["SWITCHPILOT_LANGUAGE"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }()

    public static let englishBundle: Bundle? = {
        guard let path = Bundle.main.path(forResource: "en", ofType: "lproj") else { return nil }
        return Bundle(path: path)
    }()

    public static func string(_ key: String) -> String {
        if forcedLanguage == "zh" { return key }
        if forcedLanguage == "en" {
            return englishBundle?.localizedString(forKey: key, value: key, table: nil) ?? key
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
