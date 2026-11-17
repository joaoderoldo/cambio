import Foundation

/// The badge color of a platform. Kept as plain RGB so the core stays UI-free.
public enum PlatformColor: String, Codable, CaseIterable, Sendable {
    case purple, red, blue, green, orange, teal, graphite

    public var rgb: (red: Double, green: Double, blue: Double) {
        switch self {
        case .purple: (0.40, 0.30, 0.86)
        case .red: (0.86, 0.15, 0.18)
        case .blue: (0.16, 0.47, 0.96)
        case .green: (0.16, 0.66, 0.42)
        case .orange: (0.96, 0.55, 0.13)
        case .teal: (0.10, 0.62, 0.68)
        case .graphite: (0.40, 0.42, 0.46)
        }
    }
}

/// A way money reaches the person's account (e.g. "Deel · Pix"), described by its fees.
public struct Platform: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var method: String
    public var pair: CurrencyPair
    /// Percentage taken from the amount before conversion.
    public var feePercent: Double
    /// Fixed fee in the pair's base currency, taken before conversion.
    public var fixedFee: Double
    /// How far below the commercial rate the platform converts, in percent.
    public var spreadPercent: Double
    public var color: PlatformColor

    public init(
        id: UUID = UUID(),
        name: String,
        method: String,
        pair: CurrencyPair,
        feePercent: Double,
        fixedFee: Double,
        spreadPercent: Double,
        color: PlatformColor
    ) {
        self.id = id
        self.name = name
        self.method = method
        self.pair = pair
        self.feePercent = feePercent
        self.fixedFee = fixedFee
        self.spreadPercent = spreadPercent
        self.color = color
    }

    /// First letter of the name, lowercased, as on the badge.
    public var monogram: String {
        name.trimmingCharacters(in: .whitespaces).first.map { String($0).lowercased() } ?? "?"
    }

    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && pair.base != pair.quote
            && (0...50).contains(feePercent)
            && fixedFee >= 0 && fixedFee.isFinite
            && (0...50).contains(spreadPercent)
    }

    /// A copy with a fresh id, used when adding a platform from a template.
    public func instantiated() -> Platform {
        var copy = self
        copy.id = UUID()
        return copy
    }

    /// Measured on 2026-11-17 from five simulations: a flat 1.2% fee, and a rate about 1% below commercial.
    public static let deelPix = Platform(
        id: UUID(uuidString: "D0000000-0000-4000-8000-000000000001")!,
        name: "Deel", method: "Pix", pair: .usdBrl,
        feePercent: 1.2, fixedFee: 0, spreadPercent: 1.0, color: .purple
    )

    /// Measured in Nov 2026: commercial rate minus 0.20%, no fee.
    public static let higlobePix = Platform(
        id: UUID(uuidString: "D0000000-0000-4000-8000-000000000002")!,
        name: "Higlobe", method: "Pix", pair: .usdBrl,
        feePercent: 0, fixedFee: 0, spreadPercent: 0.2, color: .red
    )

    public static func custom(color: PlatformColor) -> Platform {
        Platform(name: "", method: "Pix", pair: .usdBrl, feePercent: 0, fixedFee: 0, spreadPercent: 0, color: color)
    }
}
