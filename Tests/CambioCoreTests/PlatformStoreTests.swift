import Foundation
import Testing
@testable import CambioCore

@MainActor
struct PlatformStoreTests {
    let settings = InMemorySettings()
    let eurBrl = CurrencyPair(base: "EUR", quote: "BRL")

    @Test func startsEmptyWithDefaultAmount() {
        let store = PlatformStore(settings: settings)
        #expect(store.platforms.isEmpty)
        #expect(store.calculatorAmount == 1000)
    }

    @Test func addPersistsAndRestores() {
        let store = PlatformStore(settings: settings)
        let deel = Platform.deelPix.instantiated()
        let higlobe = Platform.higlobePix.instantiated()
        store.add(deel)
        store.add(higlobe)
        let reloaded = PlatformStore(settings: settings)
        #expect(reloaded.platforms == [deel, higlobe])
    }

    @Test func rejectsInvalid() {
        let store = PlatformStore(settings: settings)
        store.add(Platform.custom(color: .blue))
        #expect(store.platforms.isEmpty)
    }

    @Test func updateReplacesById() {
        let store = PlatformStore(settings: settings)
        var deel = Platform.deelPix.instantiated()
        store.add(deel)
        deel.spreadPercent = 1.04
        store.update(deel)
        #expect(PlatformStore(settings: settings).platform(id: deel.id)?.spreadPercent == 1.04)
    }

    @Test func updateIgnoresInvalidOrUnknown() {
        let store = PlatformStore(settings: settings)
        var deel = Platform.deelPix.instantiated()
        store.add(deel)
        deel.name = ""
        store.update(deel)
        store.update(Platform.higlobePix.instantiated())
        #expect(store.platforms.count == 1)
        #expect(store.platforms.first?.name == "Deel")
    }

    @Test func removeAllKeepsAmount() {
        let store = PlatformStore(settings: settings)
        store.calculatorAmount = 5000
        let deel = Platform.deelPix.instantiated()
        let higlobe = Platform.higlobePix.instantiated()
        store.add(deel)
        store.add(higlobe)
        store.remove(id: deel.id)
        store.remove(id: higlobe.id)
        #expect(store.platforms.isEmpty)
        let reloaded = PlatformStore(settings: settings)
        #expect(reloaded.platforms.isEmpty)
        #expect(reloaded.calculatorAmount == 5000)
    }

    @Test func pairsAndBases() {
        let store = PlatformStore(settings: settings)
        store.add(Platform.deelPix.instantiated())
        var euro = Platform.custom(color: .teal)
        euro.name = "Wise"
        euro.pair = eurBrl
        store.add(euro)
        store.add(Platform.higlobePix.instantiated())
        #expect(store.pairs == [.usdBrl, eurBrl])
        #expect(store.baseCurrencies == ["USD", "EUR"])
    }

    @Test func negativeAmountClampsToZero() {
        let store = PlatformStore(settings: settings)
        store.calculatorAmount = -10
        #expect(store.calculatorAmount == 0)
    }

    @Test func baseFallsBackWhenPreferredIsGone() {
        let store = PlatformStore(settings: settings)
        #expect(store.baseCurrency(preferring: "EUR", fallback: "EUR") == "EUR")
        store.add(Platform.deelPix.instantiated())
        #expect(store.baseCurrency(preferring: "EUR", fallback: "EUR") == "USD")
        #expect(store.baseCurrency(preferring: "USD", fallback: "EUR") == "USD")
    }
}
