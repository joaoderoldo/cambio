import Foundation

/// URLs and response decoding for https://economia.awesomeapi.com.br (free, no key).
public enum AwesomeAPI {
    public enum Failure: Error, Equatable {
        case missingPair(String)
        case invalidNumber(String)
    }

    public static let host = URL(string: "https://economia.awesomeapi.com.br")!
    public static let pairsURL = host.appending(path: "json/available")
    public static let namesURL = host.appending(path: "json/available/uniq")

    public static func latestURL(for pair: CurrencyPair) -> URL {
        latestURL(for: [pair])
    }

    /// Several pairs in one request, e.g. `/json/last/USD-BRL,EUR-BRL`. One unknown pair
    /// makes the whole request fail with 404.
    public static func latestURL(for pairs: [CurrencyPair]) -> URL {
        host.appending(path: "json/last/\(pairs.map(\.id).joined(separator: ","))")
    }

    public static func historyURL(for pair: CurrencyPair, days: Int) -> URL {
        host.appending(path: "json/daily/\(pair.id)/\(days)")
    }

    /// The API sends every number as a string; history entries after the first omit most fields.
    private struct Raw: Decodable {
        let bid: String
        let high: String?
        let low: String?
        let pctChange: String?
        let timestamp: String
    }

    public static func decodeLatest(_ data: Data, pair: CurrencyPair) throws -> Quote {
        let entries = try JSONDecoder().decode([String: Raw].self, from: data)
        guard let raw = entries[pair.responseKey] else {
            throw Failure.missingPair(pair.responseKey)
        }
        return try quote(from: raw, pair: pair)
    }

    /// Quotes for the pairs present in a batched response; absent pairs are left out.
    public static func decodeLatest(_ data: Data, pairs: [CurrencyPair]) throws -> [CurrencyPair: Quote] {
        let entries = try JSONDecoder().decode([String: Raw].self, from: data)
        var quotes: [CurrencyPair: Quote] = [:]
        for pair in pairs {
            if let raw = entries[pair.responseKey] {
                quotes[pair] = try quote(from: raw, pair: pair)
            }
        }
        return quotes
    }

    private static func quote(from raw: Raw, pair: CurrencyPair) throws -> Quote {
        let bid = try number(raw.bid, field: "bid")
        return Quote(
            pair: pair,
            bid: bid,
            high: try raw.high.map { try number($0, field: "high") } ?? bid,
            low: try raw.low.map { try number($0, field: "low") } ?? bid,
            changePercent: try raw.pctChange.map { try number($0, field: "pctChange") } ?? 0,
            timestamp: Date(timeIntervalSince1970: try number(raw.timestamp, field: "timestamp"))
        )
    }

    /// Oldest first. Entries with unparsable numbers are skipped.
    public static func decodeHistory(_ data: Data) throws -> [DailyPoint] {
        try JSONDecoder().decode([Raw].self, from: data)
            .compactMap { raw in
                guard let value = Double(raw.bid), let seconds = Double(raw.timestamp) else { return nil }
                return DailyPoint(date: Date(timeIntervalSince1970: seconds), value: value)
            }
            .sorted { $0.date < $1.date }
    }

    public static func decodeCatalog(pairs: Data, names: Data) throws -> Catalog {
        let pairIDs = try JSONDecoder().decode([String: String].self, from: pairs).keys
        let apiNames = try JSONDecoder().decode([String: String].self, from: names)
        return Catalog(pairs: Set(pairIDs), apiNames: apiNames)
    }

    private static func number(_ text: String, field: String) throws -> Double {
        guard let value = Double(text) else { throw Failure.invalidNumber(field) }
        return value
    }
}
