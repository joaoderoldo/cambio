import CambioCore
import SwiftUI

extension PlatformColor {
    var color: Color {
        let rgb = self.rgb
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}

/// A platform is a rounded square with its initial; a currency is a circle. The shape alone
/// tells them apart.
struct PlatformBadge: View {
    let platform: Platform
    var size: CGFloat = 24

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(platform.color.color.gradient)
            .frame(width: size, height: size)
            .overlay(
                Text(verbatim: platform.monogram)
                    .font(.system(size: size * 0.58, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .offset(y: -size * 0.03)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            )
            .accessibilityHidden(true)
    }
}

/// How payout numbers read on screen.
enum PayoutText {
    /// What one unit is worth through a platform, e.g. "R$ 5,66".
    static func rate(_ value: Double, quote: String) -> String {
        RateFormat.money(value, code: quote, fractionDigits: RateFormat.fractionDigits(for: value, compact: true))
    }

    /// A received amount, e.g. "R$ 28.282".
    static func total(_ value: Double, quote: String) -> String {
        RateFormat.money(value, code: quote, fractionDigits: RateFormat.fractionDigits(for: value, compact: true))
    }

    /// What is lost against the commercial rate, in whole units once it reaches one ("R$ 633").
    static func loss(_ value: Double, quote: String) -> String {
        RateFormat.money(abs(value), code: quote, fractionDigits: abs(value) >= 1 ? 0 : 2)
    }

    /// "−2,2%": what the platform costs against the commercial rate.
    static func cost(_ platform: Platform) -> String {
        "−" + RateFormat.percent(Payout.costPercent(platform), fractionDigits: 1)
    }

    /// "fee 1,2% + rate −1,0%".
    static func summary(_ platform: Platform) -> String {
        var parts: [String] = []
        if platform.feePercent > 0 {
            parts.append(String(localized: "fee \(RateFormat.percent(platform.feePercent, fractionDigits: 1))"))
        }
        if platform.fixedFee > 0 {
            parts.append(RateFormat.money(platform.fixedFee, code: platform.pair.base, fractionDigits: 2))
        }
        if platform.spreadPercent > 0 {
            parts.append(String(localized: "rate −\(RateFormat.percent(platform.spreadPercent, fractionDigits: 1))"))
        }
        let text = parts.isEmpty ? String(localized: "No fees") : parts.joined(separator: " + ")
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}

/// Small caps section title, e.g. "RECEIVING VIA".
struct SectionLabel: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }
}

/// A short gray note with an info icon.
struct FootNote: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: "info.circle").font(.system(size: 10))
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 10.5))
        .foregroundStyle(.tertiary)
    }
}
