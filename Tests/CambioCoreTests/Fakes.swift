import Foundation
@testable import CambioCore

struct Offline: Error {}

/// Programmable stand-in for the network. Quotes are built for whatever pair is asked.
actor FakeClient: RateFetching {
    var bid = 5.776
    var failLatest = false
    var failHistory = false
    var catalogToReturn: Catalog?
    private(set) var latestCalls = 0

    func setFailLatest(_ value: Bool) { failLatest = value }
    func setFailHistory(_ value: Bool) { failHistory = value }
    func setCatalog(_ value: Catalog?) { catalogToReturn = value }

    func latest(_ pair: CurrencyPair) async throws -> Quote {
        latestCalls += 1
        if failLatest { throw Offline() }
        return Quote(pair: pair, bid: bid, high: bid + 0.03, low: bid - 0.02, changePercent: -0.13,
                     timestamp: Date(timeIntervalSince1970: 1_794_925_571))
    }

    func history(_ pair: CurrencyPair, days: Int) async throws -> [DailyPoint] {
        if failHistory { throw Offline() }
        return [DailyPoint(date: Date(timeIntervalSince1970: 1_794_605_388), value: 5.66),
                DailyPoint(date: Date(timeIntervalSince1970: 1_794_925_189), value: 5.77)]
    }

    func catalog() async throws -> Catalog {
        guard let catalogToReturn else { throw Offline() }
        return catalogToReturn
    }
}

final class TestClock: @unchecked Sendable {
    var now = Date(timeIntervalSince1970: 1_794_925_600)
}

func freshDefaults() -> UserDefaults {
    UserDefaults(suiteName: "cambio-tests-\(UUID().uuidString)")!
}
