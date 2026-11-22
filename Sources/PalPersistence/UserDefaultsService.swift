import Foundation
import PalCore
import os

/// The production ``DefaultsStorage``: property-list-native values are stored
/// directly (keeping `@AppStorage` and plist interop), complex `Codable` values
/// are stored as JSON data.
///
/// `@unchecked Sendable` justification: the only mutable-reference state is
/// `UserDefaults`, which Apple documents as thread-safe; the SDK simply lacks
/// the `Sendable` annotation.
public struct UserDefaultsService: DefaultsStorage, @unchecked Sendable {

    private let defaults: UserDefaults
    private let logger = LoggerFactory.make(category: "Persistence")

    /// Creates a service over the given defaults store.
    /// - Parameter defaults: The backing store. Defaults to `.standard`.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func get<V>(_ key: DefaultsKey<V>) -> V? {
        guard let object = defaults.object(forKey: key.name) else {
            return key.defaultValue
        }
        if let value = object as? V {
            return value
        }
        if let data = object as? Data, let decoded = try? JSONDecoder().decode(V.self, from: data) {
            return decoded
        }
        logger.error("Stored value for defaults key \(key.name, privacy: .public) has an unexpected type")
        return key.defaultValue
    }

    public func set<V>(_ value: V, for key: DefaultsKey<V>) {
        if let native = plistNative(value) {
            defaults.set(native, forKey: key.name)
            return
        }
        guard let data = try? JSONEncoder().encode(value) else {
            logger.error("Failed to encode value for defaults key \(key.name, privacy: .public)")
            return
        }
        defaults.set(data, forKey: key.name)
    }

    public func delete<V>(_ key: DefaultsKey<V>) {
        defaults.removeObject(forKey: key.name)
    }

    private func plistNative<V>(_ value: V) -> Any? {
        switch value {
        case let native as String: native
        case let native as Int: native
        case let native as Double: native
        case let native as Float: native
        case let native as Bool: native
        case let native as Date: native
        case let native as Data: native
        default: nil
        }
    }
}
