import Foundation

extension [AnyHashable: Any] {

    /// The entries with string keys whose values are strings (or numbers,
    /// stringified) — the `Sendable` subset carried into response values.
    var stringValues: [String: String] {
        reduce(into: [:]) { result, pair in
            guard let key = pair.key as? String else { return }
            if let value = pair.value as? String {
                result[key] = value
            } else if let number = pair.value as? NSNumber {
                result[key] = number.stringValue
            }
        }
    }
}
