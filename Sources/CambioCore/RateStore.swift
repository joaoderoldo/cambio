import Foundation
import Observation

/// Everything the menu bar shows, kept fresh on a timer and remembered between launches.
@MainActor
@Observable
public final class RateStore {
    public private(set) var pair: CurrencyPair
    public private(set) var quote: Quote?
    public private(set) var history: [DailyPoint] = []
    public private(set) var catalog: Catalog
    public private(set) var isOffline = false
    public private(set) var isRunning = false
    public var isLoading: Bool { inFlight > 0 }

    private var inFlight = 0
    @ObservationIgnored private let client: any RateFetching
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var lastSuccess: Date?
    @ObservationIgnored private var loop: Task<Void, Never>?

    private enum Key {
        static let pair = "cambio.pair"
        static let quote = "cambio.lastQuote"
        static let catalog = "cambio.catalog"
    }

    public init(
        client: any RateFetching,
        defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.defaults = defaults
        self.now = now
        let pair = defaults.string(forKey: Key.pair).flatMap(CurrencyPair.init(id:)) ?? .usdBrl
        let cached = Self.load(Quote.self, from: defaults, key: Key.quote)
        self.pair = pair
        self.quote = cached?.pair == pair ? cached : nil
        self.catalog = Self.load(Catalog.self, from: defaults, key: Key.catalog) ?? .empty
    }

    /// Fetches the latest quote, then the 30-day history. A failed quote keeps the last one
    /// and marks the store offline; a failed history alone keeps the old chart.
    public func refresh() async {
        let requested = pair
        inFlight += 1
        defer { inFlight -= 1 }

        let latest: Quote
        do {
            latest = try await client.latest(requested)
        } catch {
            if requested == pair { isOffline = true }
            return
        }
        guard requested == pair else { return }
        quote = latest
        isOffline = false
        lastSuccess = now()
        Self.save(latest, to: defaults, key: Key.quote)

        if let points = try? await client.history(requested, days: 30), requested == pair {
            history = points
        }
    }

    /// Refreshes unless the last successful fetch is younger than `seconds`.
    public func refreshIfStale(olderThan seconds: TimeInterval) async {
        if let lastSuccess, now().timeIntervalSince(lastSuccess) < seconds { return }
        await refresh()
    }

    /// Loads the list of pairs. If the saved pair is no longer offered, falls back to USD-BRL.
    public func loadCatalog() async {
        guard let fetched = try? await client.catalog(), !fetched.pairs.isEmpty else { return }
        catalog = fetched
        Self.save(fetched, to: defaults, key: Key.catalog)
        if !fetched.contains(pair) {
            await select(.usdBrl)
        }
    }

    public func select(_ newPair: CurrencyPair) async {
        guard newPair != pair else { return }
        pair = newPair
        quote = nil
        history = []
        lastSuccess = nil
        defaults.set(newPair.id, forKey: Key.pair)
        defaults.removeObject(forKey: Key.quote)
        await refresh()
    }

    /// Starts the refresh loop once; calling it again while running does nothing.
    public func start(interval: Duration = .seconds(60)) {
        guard loop == nil else { return }
        isRunning = true
        loop = Task { [weak self] in
            await self?.loadCatalog()
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                try? await Task.sleep(for: interval)
            }
        }
    }

    public func stop() {
        loop?.cancel()
        loop = nil
        isRunning = false
    }

    private static func load<T: Decodable>(_ type: T.Type, from defaults: UserDefaults, key: String) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    private static func save<T: Encodable>(_ value: T, to defaults: UserDefaults, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }
}
