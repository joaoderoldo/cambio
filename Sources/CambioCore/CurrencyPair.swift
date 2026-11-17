import Foundation

/// A currency pair as AwesomeAPI names it, e.g. `USD-BRL` (1 USD priced in BRL).
public struct CurrencyPair: Hashable, Codable, Sendable {
    public let base: String
    public let quote: String

    public init(base: String, quote: String) {
        self.base = base
        self.quote = quote
    }

    /// Parses `"USD-BRL"`. Returns nil unless there are exactly two non-empty parts.
    public init?(id: String) {
        let parts = id.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        self.init(base: String(parts[0]), quote: String(parts[1]))
    }

    /// `"USD-BRL"`, the form used in AwesomeAPI URLs.
    public var id: String { "\(base)-\(quote)" }

    /// `"USDBRL"`, the key used in `/json/last` responses.
    public var responseKey: String { base + quote }

    public var swapped: CurrencyPair { CurrencyPair(base: quote, quote: base) }

    public static let usdBrl = CurrencyPair(base: "USD", quote: "BRL")
}
