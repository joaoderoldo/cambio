import Foundation

/// Which pairs AwesomeAPI offers and what it calls each currency.
public struct Catalog: Codable, Equatable, Sendable {
    /// Pair ids such as `"USD-BRL"`.
    public let pairs: Set<String>
    /// Currency names as the API sends them (in Portuguese), keyed by code.
    public let apiNames: [String: String]

    public init(pairs: Set<String>, apiNames: [String: String]) {
        self.pairs = pairs
        self.apiNames = apiNames
    }
}

extension Catalog {
    public static let empty = Catalog(pairs: [], apiNames: [:])

    public func contains(_ pair: CurrencyPair) -> Bool {
        pairs.contains(pair.id)
    }

    /// Every currency that can be the "from" side, alphabetically.
    public var bases: [String] {
        Set(parsedPairs.map(\.base)).sorted()
    }

    /// Every currency `base` can be priced in, alphabetically.
    public func quotes(for base: String) -> [String] {
        Set(parsedPairs.filter { $0.base == base }.map(\.quote)).sorted()
    }

    /// The system's name for ISO currencies (so it follows the UI language),
    /// then the API's name (e.g. BRLT, BRLPTAX), then the code itself.
    public func displayName(for code: String, locale: Locale = .current) -> String {
        if let special = Self.specialNames[code] {
            return locale.language.languageCode == .portuguese ? special.portuguese : special.english
        }
        if let localized = locale.localizedString(forCurrencyCode: code),
           localized.caseInsensitiveCompare(code) != .orderedSame {
            return localized
        }
        return apiNames[code] ?? code
    }

    /// Keeps the codes whose code, currency name or country name contains `query`,
    /// ignoring case and accents ("mexico" finds MXN, "suíça" finds CHF, "europe" finds EUR).
    public func search(_ codes: [String], query: String, locale: Locale = .current) -> [String] {
        let needle = fold(query.trimmingCharacters(in: .whitespacesAndNewlines), locale: locale)
        guard !needle.isEmpty else { return codes }
        return codes.filter { code in
            let country = CurrencyArt.region(for: code).flatMap { locale.localizedString(forRegionCode: $0) }
            return fold(code, locale: locale).contains(needle)
                || fold(displayName(for: code, locale: locale), locale: locale).contains(needle)
                || country.map { fold($0, locale: locale).contains(needle) } == true
        }
    }

    /// The API calls PTAX and the tourism rate plain "Real Brasileiro"; say what they are.
    private static let specialNames: [String: (english: String, portuguese: String)] = [
        "BRLPTAX": ("Brazilian Real (PTAX)", "Real (PTAX)"),
        "BRLT": ("Brazilian Real (tourism)", "Real turismo"),
    ]

    private var parsedPairs: [CurrencyPair] {
        pairs.compactMap(CurrencyPair.init(id:))
    }

    private func fold(_ text: String, locale: Locale) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
    }
}
