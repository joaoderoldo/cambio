import Foundation

public protocol RateFetching: Sendable {
    /// Latest quotes for several pairs in one request. Pairs missing from the answer are left out.
    func latest(_ pairs: [CurrencyPair]) async throws -> [CurrencyPair: Quote]
    func history(_ pair: CurrencyPair, days: Int) async throws -> [DailyPoint]
    func catalog() async throws -> Catalog
}

extension RateFetching {
    public func latest(_ pair: CurrencyPair) async throws -> Quote {
        guard let quote = try await latest([pair])[pair] else {
            throw AwesomeAPI.Failure.missingPair(pair.responseKey)
        }
        return quote
    }
}

/// Talks to AwesomeAPI. The loader is injectable so tests never touch the network.
public struct AwesomeAPIClient: RateFetching {
    public typealias Loader = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let load: Loader

    public init(load: @escaping Loader = { try await URLSession.shared.data(for: $0) }) {
        self.load = load
    }

    public func latest(_ pairs: [CurrencyPair]) async throws -> [CurrencyPair: Quote] {
        try AwesomeAPI.decodeLatest(try await get(AwesomeAPI.latestURL(for: pairs)), pairs: pairs)
    }

    public func history(_ pair: CurrencyPair, days: Int) async throws -> [DailyPoint] {
        try AwesomeAPI.decodeHistory(try await get(AwesomeAPI.historyURL(for: pair, days: days)))
    }

    public func catalog() async throws -> Catalog {
        async let pairs = get(AwesomeAPI.pairsURL)
        async let names = get(AwesomeAPI.namesURL)
        return try AwesomeAPI.decodeCatalog(pairs: try await pairs, names: try await names)
    }

    private func get(_ url: URL) async throws -> Data {
        // The API already caches unauthenticated responses; skip the local cache so
        // "Refresh" always asks the server.
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        let (data, response) = try await load(request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
