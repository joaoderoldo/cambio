import Foundation
import Testing
@testable import CambioCore

@MainActor
struct RateStoreTests {
    let client = FakeClient()
    let clock = TestClock()
    let defaults = InMemorySettings()
    let eurBrl = CurrencyPair(base: "EUR", quote: "BRL")

    func makeStore(defaults: InMemorySettings? = nil, extraPairs: Set<CurrencyPair> = []) -> RateStore {
        let clock = self.clock
        return RateStore(client: client, defaults: defaults ?? self.defaults, now: { clock.now }, extraPairs: { extraPairs })
    }

    @Test func refreshFetchesExtraPairs() async {
        let store = makeStore(extraPairs: [eurBrl])
        await store.refresh()
        #expect(store.quote(for: eurBrl)?.pair == eurBrl)
        #expect(store.quote(for: .usdBrl) == store.quote)
        #expect(await client.batches.last == [.usdBrl, eurBrl])
    }

    @Test func badExtraPairFallsBack() async {
        let unknown = CurrencyPair(base: "XYZ", quote: "BRL")
        await client.setUnknownPairs([unknown])
        let store = makeStore(extraPairs: [unknown])
        await store.refresh()
        #expect(store.quote != nil)
        #expect(!store.isOffline)
        #expect(store.quote(for: unknown) == nil)
        #expect(await client.batches == [[.usdBrl, unknown], [.usdBrl]])
    }

    @Test func refreshSuccess() async {
        let store = makeStore()
        await store.refresh()
        #expect(store.quote?.bid == 5.776)
        #expect(store.history.map(\.value) == [5.66, 5.77])
        #expect(!store.isOffline)
        #expect(!store.isLoading)
    }

    @Test func refreshFailureKeepsLastQuote() async {
        let store = makeStore()
        await store.refresh()
        await client.setFailLatest(true)
        await store.refresh()
        #expect(store.quote?.bid == 5.776)
        #expect(store.isOffline)
    }

    @Test func historyFailureIsNotOffline() async {
        await client.setFailHistory(true)
        let store = makeStore()
        await store.refresh()
        #expect(!store.isOffline)
        #expect(store.quote != nil)
        #expect(store.history.isEmpty)
        await client.setFailHistory(false)
        await store.refresh()
        #expect(store.history.count == 2)
    }

    @Test func historyIsFetchedAtMostHourly() async {
        let store = makeStore()
        await store.refresh()
        await store.refresh()
        #expect(await client.historyCalls == 1)
        clock.now += 3601
        await store.refresh()
        #expect(await client.historyCalls == 2)
        await store.select(eurBrl)
        #expect(await client.historyCalls == 3)
    }

    @Test func overlappingRefreshLatestWins() async throws {
        // An older request that fails late must not mark fresh data as offline.
        await client.setScript([(delay: .milliseconds(300), fail: true), (delay: .zero, fail: false)])
        let store = makeStore()
        async let slow: Void = store.refresh()
        try await Task.sleep(for: .milliseconds(50))
        await store.refresh()
        #expect(!store.isOffline)
        await slow
        #expect(!store.isOffline)
        #expect(store.quote != nil)
    }

    @Test func firstLaunchOffline() async {
        await client.setFailLatest(true)
        let store = makeStore()
        await store.refresh()
        #expect(store.quote == nil)
        #expect(store.isOffline)
    }

    @Test func restoresFromDefaults() async {
        let first = makeStore()
        await first.select(eurBrl)
        let second = makeStore()
        #expect(second.pair == eurBrl)
        #expect(second.quote?.pair == eurBrl)
        #expect(second.quote?.bid == 5.776)
    }

    @Test func ignoresCachedQuoteOfOtherPair() async {
        let first = makeStore()
        await first.refresh()
        defaults.set("EUR-BRL", forKey: "cambio.pair")
        let second = makeStore()
        #expect(second.pair == eurBrl)
        #expect(second.quote == nil)
    }

    @Test func selectSamePairIsNoop() async {
        let store = makeStore()
        await store.refresh()
        await store.select(.usdBrl)
        #expect(await client.latestCalls == 1)
    }

    @Test func selectPersistsAndRefreshes() async {
        let store = makeStore()
        await store.refresh()
        await store.select(eurBrl)
        #expect(defaults.string(forKey: "cambio.pair") == "EUR-BRL")
        #expect(store.pair == eurBrl)
        #expect(store.quote?.pair == eurBrl)
    }

    @Test func stalePairFallsBack() async {
        defaults.set("XYZ-BRL", forKey: "cambio.pair")
        await client.setCatalog(Catalog(pairs: ["USD-BRL", "EUR-BRL"], apiNames: [:]))
        let store = makeStore()
        #expect(store.pair == CurrencyPair(base: "XYZ", quote: "BRL"))
        await store.loadCatalog()
        #expect(store.pair == .usdBrl)
        #expect(store.catalog.pairs == ["USD-BRL", "EUR-BRL"])
        #expect(makeStore().catalog.pairs == ["USD-BRL", "EUR-BRL"])
    }

    @Test func catalogRetriesUntilLoadedThenDaily() async {
        // Launch at login often starts before Wi-Fi: the first catalog fetch fails.
        defaults.set("XYZ-BRL", forKey: "cambio.pair")
        let store = makeStore()
        await store.loadCatalogIfNeeded()
        #expect(store.pair == CurrencyPair(base: "XYZ", quote: "BRL"))
        await client.setCatalog(Catalog(pairs: ["USD-BRL"], apiNames: [:]))
        await store.loadCatalogIfNeeded()
        #expect(store.pair == .usdBrl)
        await store.loadCatalogIfNeeded()
        #expect(await client.catalogCalls == 2)
        clock.now += 25 * 3600
        await store.loadCatalogIfNeeded()
        #expect(await client.catalogCalls == 3)
    }

    @Test func catalogFailureKeepsPair() async {
        defaults.set("EUR-BRL", forKey: "cambio.pair")
        let store = makeStore()
        await store.loadCatalog()
        #expect(store.pair == eurBrl)
        #expect(store.catalog == .empty)
    }

    @Test func refreshIfStale() async {
        let store = makeStore()
        await store.refresh()
        clock.now += 10
        await store.refreshIfStale(olderThan: 15)
        #expect(await client.latestCalls == 1)
        clock.now += 10
        await store.refreshIfStale(olderThan: 15)
        #expect(await client.latestCalls == 2)
    }

    @Test func refreshIfStaleRetriesWhileOffline() async {
        await client.setFailLatest(true)
        let store = makeStore()
        await store.refresh()
        await store.refreshIfStale(olderThan: 15)
        #expect(await client.latestCalls == 2)
    }

    @Test func startIsIdempotent() async throws {
        let store = makeStore()
        store.start(interval: .seconds(3600))
        store.start(interval: .seconds(3600))
        #expect(store.isRunning)
        try await Task.sleep(for: .milliseconds(300))
        #expect(await client.latestCalls == 1)
        store.stop()
        #expect(!store.isRunning)
    }

    @Test func freshnessTracksSuccessfulFetches() async {
        let store = makeStore(extraPairs: [eurBrl])
        #expect(!store.isFresh(.usdBrl, within: 120))
        await store.refresh()
        #expect(store.isFresh(.usdBrl, within: 120))
        #expect(store.isFresh(eurBrl, within: 120))
        clock.now += 200
        #expect(!store.isFresh(.usdBrl, within: 120))
        await client.setFailLatest(true)
        await store.refresh()
        #expect(!store.isFresh(.usdBrl, within: 120))
    }

    @Test func cachedQuoteIsNotFresh() async {
        let first = makeStore()
        await first.refresh()
        let second = makeStore()
        #expect(second.quote != nil)
        #expect(!second.isFresh(.usdBrl, within: 120))
    }

    @Test func fetchQuoteForUntrackedPair() async {
        let store = makeStore()
        await store.fetchQuote(for: eurBrl)
        #expect(store.quote(for: eurBrl)?.pair == eurBrl)
        #expect(store.isFresh(eurBrl, within: 60))
        await client.setFailLatest(true)
        let gbpBrl = CurrencyPair(base: "GBP", quote: "BRL")
        await store.fetchQuote(for: gbpBrl)
        #expect(store.quote(for: gbpBrl) == nil)
        #expect(!store.isOffline)
    }

    @Test func lastCheckedIsTheTimeOfTheLastSuccessfulFetch() async {
        let store = makeStore()
        #expect(store.lastChecked == nil)
        await store.refresh()
        #expect(store.lastChecked == clock.now)
        let checked = clock.now
        clock.now += 60
        await client.setFailLatest(true)
        await store.refresh()
        #expect(store.lastChecked == checked)
        #expect(makeStore().lastChecked == nil)
    }
}
