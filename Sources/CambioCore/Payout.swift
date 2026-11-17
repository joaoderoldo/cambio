import Foundation

/// How much reaches the account. For an amount A at commercial rate C:
/// `max(0, A × (1 − fee%) − fixedFee) × C × (1 − spread%)`.
public enum Payout {
    public static func receive(_ amount: Double, via platform: Platform, commercial: Double) -> Double {
        let net = max(0, amount * (1 - platform.feePercent / 100) - platform.fixedFee)
        return net * commercial * (1 - platform.spreadPercent / 100)
    }

    /// What one unit of the base currency is worth through the platform, fixed fee aside
    /// (its effect depends on the amount, so it only shows in the calculator).
    public static func platformRate(_ platform: Platform, commercial: Double) -> Double {
        commercial * (1 - platform.feePercent / 100) * (1 - platform.spreadPercent / 100)
    }

    /// Percent lost against the commercial rate, fixed fee aside.
    public static func costPercent(_ platform: Platform) -> Double {
        (1 - (1 - platform.feePercent / 100) * (1 - platform.spreadPercent / 100)) * 100
    }

    /// The spread implied by the rate a platform shows next to the commercial rate of the
    /// same minute, clamped to 0…20% and rounded to two decimals. Nil without valid inputs.
    public static func spread(platformRate: Double, commercial: Double) -> Double? {
        guard platformRate > 0, commercial > 0, platformRate.isFinite, commercial.isFinite else { return nil }
        let raw = (1 - platformRate / commercial) * 100
        return (min(max(raw, 0), 20) * 100).rounded() / 100
    }
}
