import Foundation

/// Photo search filters; nil means any. Raw values are the Pexels values.
nonisolated struct SearchFilters: Hashable, Sendable {
    nonisolated enum Orientation: String, CaseIterable, Sendable {
        case landscape, portrait, square
    }

    /// The smallest a photo may be: large is 24 MP, medium 12 MP and small 4 MP.
    nonisolated enum Size: String, CaseIterable, Sendable {
        case large, medium, small
    }

    /// The colours Pexels names. It also takes any hex colour, which the app does not offer.
    nonisolated enum ColorName: String, CaseIterable, Sendable {
        case red, orange, yellow, green, turquoise, blue, violet, pink, brown, black, gray, white
    }

    /// The language of the search words (the Pexels `locale`).
    nonisolated enum Language: String, CaseIterable, Sendable {
        case english = "en-US", portuguese = "pt-BR", spanish = "es-ES", catalan = "ca-ES"
        case german = "de-DE", italian = "it-IT", french = "fr-FR", swedish = "sv-SE"
        case indonesian = "id-ID", polish = "pl-PL", japanese = "ja-JP"
        case chineseTraditional = "zh-TW", chineseSimplified = "zh-CN", korean = "ko-KR"
        case thai = "th-TH", dutch = "nl-NL", hungarian = "hu-HU", vietnamese = "vi-VN"
        case czech = "cs-CZ", danish = "da-DK", finnish = "fi-FI", ukrainian = "uk-UA"
        case greek = "el-GR", romanian = "ro-RO", norwegian = "nb-NO", slovak = "sk-SK"
        case turkish = "tr-TR", russian = "ru-RU"

        var languageCode: String { String(rawValue.prefix { $0 != Constants.localeSeparator }) }

        /// The supported language for a phone set to `locale`, such as German for de-AT; nil if none.
        static func matching(_ locale: Locale) -> Language? {
            guard let code = locale.language.languageCode?.identifier else { return nil }
            guard code != Constants.chineseCode else {
                let isTraditional = locale.language.maximalIdentifier.contains(Constants.traditionalScript)
                return isTraditional ? .chineseTraditional : .chineseSimplified
            }
            return allCases.first { $0.languageCode == code }
        }
    }

    private enum Constants {
        static let localeSeparator: Character = "-"
        static let chineseCode = "zh"
        static let traditionalScript = "Hant"
    }

    private enum Parameter {
        static let orientation = "orientation"
        static let size = "size"
        static let color = "color"
        static let locale = "locale"
    }

    var orientation: Orientation?
    var size: Size?
    var color: ColorName?
    var language: Language?

    var isEmpty: Bool { self == SearchFilters() }

    /// A fixed order, so equal filters share one offline copy.
    var queryItems: [URLQueryItem] {
        let pairs: [(String, String?)] = [(Parameter.orientation, orientation?.rawValue),
                                          (Parameter.size, size?.rawValue),
                                          (Parameter.color, color?.rawValue),
                                          (Parameter.locale, language?.rawValue)]
        return pairs.compactMap { name, value in value.map { URLQueryItem(name: name, value: $0) } }
    }
}
