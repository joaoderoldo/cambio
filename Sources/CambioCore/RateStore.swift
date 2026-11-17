import Foundation
import Observation

/// Everything the menu bar shows, kept fresh on a timer and remembered between launches.
@MainActor
@Observable
public final class RateStore {
    public private(set) var pair: CurrencyPair
    public private(set) var quote: Quote?
    public private(set) var history: [DailyPoint] = []
    /// Latest quotes for the bar's pair and every extra pair (the platforms' pairs).
    public private(set) var quotes: [CurrencyPair: Quote] = [:]
    public private(set) var catalog: Catalog
    public private(set) var isOffline = false
    public private(set) var isRunning = false
    public var isLoading: Bool { inFlight > 0 }

    private var inFlight = 0
    @ObservationIgnored private let client: any RateFetching
    @ObservationIgnored private let defaults: any SettingsStore
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let extraPairs: @MainActor () -> Set<CurrencyPair>
    @ObservationIgnored private var lastSuccess: Date?
    @ObservationIgnored private var lastHistorySuccess: Date?
    @ObservationIgnored private var lastCatalogSuccess: Date?
    /// Only the most recently started refresh may change state; older ones finish silently.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var loop: Task<Void, Never>?

    private enum Key {
        static let pair = "cambio.pair"
        static let quote = "cambio.lastQuote"
        static let catalog = "cambio.catalog"
    }

    public init(
        client: any RateFetching,
        defaults: any SettingsStore = UserDefaults.standard,
        now: @escaping @Sendable () -> Date = { Date() },
        extraPairs: @escaping @MainActor () -> Set<CurrencyPair> = { [] }
    ) {
        self.client = client
        self.defaults = defaults
        self.now = now
        self.extraPairs = extraPairs
        let pair = defaults.string(forKey: Key.pair).flatMap(CurrencyPair.init(id:)) ?? .usdBrl
        let cached = Self.load(Quote.self, from: defaults, key: Key.quote)
        self.pair = pair
        self.quote = cached?.pair == pair ? cached : nil
        self.catalog = Self.load(Catalog.self, from: defaults, key: Key.catalog) ?? .empty
    }

    /// Fetches the latest quote, then the 30-day history (at most hourly: it changes daily).
    /// A failed quote keeps the last one and marks the store offline; a failed history alone
    /// keeps the old chart. When refreshes overlap, only the newest one counts.
    public func refresh() async {
        let requested = pair
        generation += 1
        let current = generation
        inFlight += 1
        defer { inFlight -= 1 }

        // The bar's pair first, then the platforms' pairs, in one request. One unknown pair
        // fails the whole batch, so fall back to the bar's pair alone: the bar must keep working.
        let batch = [requested] + extraPairs().subtracting([requested]).sorted { $0.id < $1.id }
        var fetched: [CurrencyPair: Quote]
        do {
            fetched = try await client.latest(batch)
        } catch {
            if batch.count > 1, let single = try? await client.latest([requested]) {
                fetched = single
            } else {
                if current == generation, requested == pair { isOffline = true }
                return
            }
        }
        guard current == generation, requested == pair else { return }
        guard let latest = fetched[requested] else {
            isOffline = true
            return
        }
        quotes.merge(fetched) { _, new in new }
        quote = latest
        isOffline = false
        lastSuccess = now()
        Self.save(latest, to: defaults, key: Key.quote)

        let historyIsFresh = lastHistorySuccess.map { now().timeIntervalSince($0) < 3600 } ?? false
        guard history.isEmpty || !historyIsFresh else { return }
        if let points = try? await client.history(requested, days: 30), requested == pair {
            history = points
            lastHistorySuccess = now()
        }
    }

    /// The latest quote for any pair in use: the bar's own, or a platform's.
    public func quote(for pair: CurrencyPair) -> Quote? {
        pair == self.pair ? quote : quotes[pair]
    }

    /// Refreshes unless the last successful fetch is younger than `seconds`.
    public func refreshIfStale(olderThan seconds: TimeInterval) async {
        if let lastSuccess, now().timeIntervalSince(lastSuccess) < seconds { return }
        await refresh()
    }

    /// Loads the catalog unless one was loaded in this session less than `maxAge` ago.
    /// Called every cycle, so a launch without network keeps retrying until it succeeds.
    public func loadCatalogIfNeeded(maxAge: TimeInterval = 24 * 3600) async {
        if let lastCatalogSuccess, now().timeIntervalSince(lastCatalogSuccess) < maxAge { return }
        await loadCatalog()
    }

    /// Loads the list of pairs. If the saved pair is no longer offered, falls back to USD-BRL.
    public func loadCatalog() async {
        guard let fetched = try? await client.catalog(), !fetched.pairs.isEmpty else { return }
        lastCatalogSuccess = now()
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
        lastHistorySuccess = nil
        defaults.set(newPair.id, forKey: Key.pair)
        defaults.removeObject(forKey: Key.quote)
        await refresh()
    }

    /// Starts the refresh loop once; calling it again while running does nothing.
    public func start(interval: Duration = .seconds(60)) {
        guard loop == nil else { return }
        isRunning = true
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.loadCatalogIfNeeded()
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

    private static func load<T: Decodable>(_ type: T.Type, from defaults: any SettingsStore, key: String) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    private static func save<T: Encodable>(_ value: T, to defaults: any SettingsStore, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }
}
