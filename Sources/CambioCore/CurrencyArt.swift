import Foundation

/// The visual identity of each currency: a country flag, or a colored badge for crypto and metals.
public enum CurrencyArt {
    public struct Badge: Equatable, Sendable {
        public let symbol: String
        public let red: Double
        public let green: Double
        public let blue: Double

        public init(symbol: String, red: Double, green: Double, blue: Double) {
            self.symbol = symbol
            self.red = red
            self.green = green
            self.blue = blue
        }
    }

    /// Shown first in the picker, in this order.
    public static let popular = ["USD", "EUR", "GBP", "BRL", "JPY", "CAD", "AUD", "CHF", "ARS", "BTC"]

    private static let badges: [String: Badge] = [
        "BTC": Badge(symbol: "₿", red: 0.97, green: 0.58, blue: 0.10),
        "ETH": Badge(symbol: "Ξ", red: 0.38, green: 0.49, blue: 0.92),
        "LTC": Badge(symbol: "Ł", red: 0.20, green: 0.36, blue: 0.62),
        "XRP": Badge(symbol: "✕", red: 0.14, green: 0.16, blue: 0.18),
        "DOGE": Badge(symbol: "Ð", red: 0.76, green: 0.65, blue: 0.20),
        "BRETT": Badge(symbol: "B", red: 0.25, green: 0.45, blue: 0.95),
        "SOL": Badge(symbol: "◎", red: 0.58, green: 0.27, blue: 0.98),
        "BNB": Badge(symbol: "B", red: 0.95, green: 0.73, blue: 0.18),
        "USDT": Badge(symbol: "₮", red: 0.15, green: 0.63, blue: 0.48),
        "SDR": Badge(symbol: "S", red: 0.40, green: 0.45, blue: 0.55),
        "XBR": Badge(symbol: "Br", red: 0.20, green: 0.20, blue: 0.22),
        "XAU": Badge(symbol: "Au", red: 0.83, green: 0.69, blue: 0.22),
        "XAG": Badge(symbol: "Ag", red: 0.62, green: 0.63, blue: 0.66),
        "XAGG": Badge(symbol: "Ag", red: 0.62, green: 0.63, blue: 0.66),
    ]

    private static let regions: Set<String> = Set(Locale.Region.isoRegions.map(\.identifier))

    /// The issuing region. ISO 4217 codes start with the country's ISO 3166 code, so `BRL`,
    /// `BRLT` and `BRLPTAX` all map to BR, and EUR maps to EU. Crypto, metals and other
    /// supranational `X…` codes have none.
    public static func region(for code: String) -> String? {
        if badges[code] != nil { return nil }
        if code == "EUR" { return "EU" }
        if code.hasPrefix("X") { return nil }
        let region = String(code.prefix(2)).uppercased()
        guard region.count == 2, regions.contains(region) else { return nil }
        return region
    }

    public static func flag(for code: String) -> String? {
        region(for: code).map { region in
            region.unicodeScalars
                .compactMap { UnicodeScalar(127_397 + $0.value) }
                .map(String.init)
                .joined()
        }
    }

    public static func badge(for code: String) -> Badge {
        badges[code] ?? Badge(symbol: String(code.prefix(1)), red: 0.55, green: 0.55, blue: 0.55)
    }
}
