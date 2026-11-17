import Foundation

/// The latest price of a pair, as returned by `/json/last`.
public struct Quote: Codable, Equatable, Sendable {
    public let pair: CurrencyPair
    public let bid: Double
    public let high: Double
    public let low: Double
    public let changePercent: Double
    public let timestamp: Date

    public init(pair: CurrencyPair, bid: Double, high: Double, low: Double, changePercent: Double, timestamp: Date) {
        self.pair = pair
        self.bid = bid
        self.high = high
        self.low = low
        self.changePercent = changePercent
        self.timestamp = timestamp
    }
}

/// One day of history, used by the 30-day chart.
public struct DailyPoint: Codable, Equatable, Sendable, Identifiable {
    public let date: Date
    public let value: Double
    public var id: Date { date }

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}
