import Foundation

/// Number formatting for the menu bar and the panel. Every function takes a locale so the
/// decimal separator follows the system and tests stay deterministic.
public enum RateFormat {
    /// Bar (`compact`) and panel precision, by magnitude: ≥1000 → 0/2, ≥1 → 2/4, <1 → 4/6.
    public static func fractionDigits(for value: Double, compact: Bool) -> Int {
        let magnitude = abs(value)
        if magnitude >= 1000 { return compact ? 0 : 2 }
        if magnitude >= 1 { return compact ? 2 : 4 }
        return compact ? 4 : 6
    }

    public static func number(_ value: Double, fractionDigits: Int, locale: Locale = .current) -> String {
        value.formatted(.number.precision(.fractionLength(fractionDigits)).locale(locale))
    }

    /// `"USD 5,78 ▾"`. The arrow shows the day's direction and is left out when flat or unknown.
    public static func barText(base: String, value: Double?, changePercent: Double?, locale: Locale = .current) -> String {
        guard let value else { return "\(base) —" }
        let text = "\(base) \(number(value, fractionDigits: fractionDigits(for: value, compact: true), locale: locale))"
        switch changePercent {
        case let change? where change > 0: return text + " ▴"
        case let change? where change < 0: return text + " ▾"
        default: return text
        }
    }

    /// `"R$ 5,7760"`. Non-ISO quotes such as `BRLT` and `BRLPTAX` use their first three letters.
    public static func price(_ value: Double, quote: String, locale: Locale = .current) -> String {
        let digits = fractionDigits(for: value, compact: false)
        return value.formatted(.currency(code: String(quote.prefix(3))).precision(.fractionLength(digits)).locale(locale))
    }

    /// Absolute value with two decimals, e.g. `"0,14%"`. Direction is shown separately.
    public static func percent(_ value: Double, locale: Locale = .current) -> String {
        number(abs(value), fractionDigits: 2, locale: locale) + "%"
    }
}
