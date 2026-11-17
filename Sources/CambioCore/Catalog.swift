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
