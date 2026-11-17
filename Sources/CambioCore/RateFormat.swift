import Foundation

/// Number formatting for the menu bar and the panel. Every function takes a locale so the
/// decimal separator follows the system and tests stay deterministic.
public enum RateFormat {
    /// Bar (`compact`) and panel precision, by magnitude: ≥1000 → 0/2, ≥1 → 2/4. Below 1,
    /// about 3 (bar) or 5 (panel) significant digits, at least 4/6 and at most 10, so tiny
    /// rates such as IRR→USD (0.00000053) never collapse to zeros.
    public static func fractionDigits(for value: Double, compact: Bool) -> Int {
        let magnitude = abs(value)
        if magnitude >= 1000 { return compact ? 0 : 2 }
        if magnitude >= 1 || magnitude == 0 || !magnitude.isFinite { return compact ? 2 : 4 }
        let leadingZeros = Int(floor(-log10(magnitude)))
        let digits = compact ? max(4, leadingZeros + 3) : max(6, leadingZeros + 5)
        return min(digits, 10)
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
        money(value, code: quote, fractionDigits: fractionDigits(for: value, compact: false), locale: locale)
    }

    /// An amount in a currency with exactly `fractionDigits` decimals, e.g. `"R$ 28.282"`.
    public static func money(_ value: Double, code: String, fractionDigits: Int, locale: Locale = .current) -> String {
        value.formatted(.currency(code: String(code.prefix(3))).precision(.fractionLength(fractionDigits)).locale(locale))
    }

    /// How current the shown quote is.
    public enum Freshness: Equatable, Sendable {
        /// The quote is about as recent as the last check: "Updated at 16:14".
        case live(Date)
        /// The source has not published anything newer (PTAX, weekends): "Rate from 13:07 · checked 16:17".
        case published(Date, checked: Date)
    }

    /// `.published` once the quote is more than `threshold` older than the last successful check.
    public static func freshness(quoteTime: Date, checkedAt: Date?, threshold: TimeInterval = 600) -> Freshness {
        guard let checkedAt, checkedAt.timeIntervalSince(quoteTime) > threshold else { return .live(quoteTime) }
        return .published(quoteTime, checked: checkedAt)
    }

    /// "16:17" for today, "sex. 13:03" for another day (weekday in the locale's language).
    public static func clockTime(
        _ date: Date, relativeTo now: Date = Date(), locale: Locale = .current, calendar: Calendar = .current
    ) -> String {
        var time = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar)
        time.timeZone = calendar.timeZone
        guard !calendar.isDate(date, inSameDayAs: now) else { return date.formatted(time) }
        var weekday = Date.FormatStyle(locale: locale, calendar: calendar).weekday(.abbreviated)
        weekday.timeZone = calendar.timeZone
        return "\(date.formatted(weekday)) \(date.formatted(time))"
    }

    /// Absolute value, e.g. `"0,14%"`. Direction is shown separately.
    public static func percent(_ value: Double, fractionDigits: Int = 2, locale: Locale = .current) -> String {
        number(abs(value), fractionDigits: fractionDigits, locale: locale) + "%"
    }
}
