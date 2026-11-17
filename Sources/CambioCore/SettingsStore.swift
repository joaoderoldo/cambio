import Foundation

/// The slice of UserDefaults that RateStore needs. Tests and screenshots use the in-memory
/// version so they never write preference files to disk.
public protocol SettingsStore: AnyObject {
    func string(forKey key: String) -> String?
    func data(forKey key: String) -> Data?
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
}

extension UserDefaults: SettingsStore {}

public final class InMemorySettings: SettingsStore {
    private var values: [String: Any] = [:]

    public init() {}

    public func string(forKey key: String) -> String? { values[key] as? String }
    public func data(forKey key: String) -> Data? { values[key] as? Data }
    public func set(_ value: Any?, forKey key: String) { values[key] = value }
    public func removeObject(forKey key: String) { values[key] = nil }
}
