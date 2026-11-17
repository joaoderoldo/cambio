import Foundation
import Testing
@testable import CambioCore

@MainActor
struct RateStoreTests {
    let client = FakeClient()
    let clock = TestClock()
    let defaults = freshDefaults()
    let eurBrl = CurrencyPair(base: "EUR", quote: "BRL")

    func makeStore(defaults: UserDefaults? = nil) -> RateStore {
        let clock = self.clock
        return RateStore(client: client, defaults: defaults ?? self.defaults, now: { clock.now })
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
        let store = makeStore()
        await store.refresh()
        await client.setFailHistory(true)
        await store.refresh()
        #expect(!store.isOffline)
        #expect(store.history.count == 2)
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
}
