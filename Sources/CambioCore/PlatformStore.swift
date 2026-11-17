import Foundation
import Observation

/// The platforms a person receives through, and the last amount typed in the calculator.
/// Both are saved locally.
@MainActor
@Observable
public final class PlatformStore {
    public private(set) var platforms: [Platform]

    /// The calculator's amount. Never negative; saved on every change.
    public var calculatorAmount: Double {
        didSet {
            if calculatorAmount < 0 { calculatorAmount = 0 }
            settings.set(String(calculatorAmount), forKey: Key.amount)
        }
    }

    @ObservationIgnored private let settings: any SettingsStore

    private enum Key {
        static let platforms = "cambio.platforms"
        static let amount = "cambio.calculatorAmount"
    }

    public init(settings: any SettingsStore = UserDefaults.standard) {
        self.settings = settings
        self.platforms = settings.data(forKey: Key.platforms)
            .flatMap { try? JSONDecoder().decode([Platform].self, from: $0) } ?? []
        self.calculatorAmount = max(0, settings.string(forKey: Key.amount).flatMap(Double.init) ?? 1000)
    }

    public func add(_ platform: Platform) {
        guard platform.isValid else { return }
        platforms.append(platform)
        save()
    }

    public func update(_ platform: Platform) {
        guard platform.isValid, let index = platforms.firstIndex(where: { $0.id == platform.id }) else { return }
        platforms[index] = platform
        save()
    }

    public func remove(id: UUID) {
        platforms.removeAll { $0.id == id }
        save()
    }

    public func platform(id: UUID) -> Platform? {
        platforms.first { $0.id == id }
    }

    public var pairs: Set<CurrencyPair> {
        Set(platforms.map(\.pair))
    }

    /// Source currencies in the order they first appear.
    public var baseCurrencies: [String] {
        var seen: [String] = []
        for platform in platforms where !seen.contains(platform.pair.base) {
            seen.append(platform.pair.base)
        }
        return seen
    }

    private func save() {
        if let data = try? JSONEncoder().encode(platforms) {
            settings.set(data, forKey: Key.platforms)
        }
    }
}
