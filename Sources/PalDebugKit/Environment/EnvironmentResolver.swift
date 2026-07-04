import Foundation
import PalPersistence

/// Resolves the active base URL **synchronously and off the main actor**, so it
/// can back an `HTTPClient`'s `baseURLProvider`. It reads the selection that
/// `EnvironmentStore` persists, so switching environments takes effect on the
/// next request with no client rebuild.
public enum EnvironmentResolver {

    /// The active base URL for a client, or `fallback` if none is selected.
    /// - Parameters:
    ///   - clientID: The client. Defaults to ``ClientID/default``.
    ///   - fallback: The URL to use before any selection (typically the app's default).
    ///   - defaults: The UserDefaults access. Defaults to the standard suite.
    public static func baseURL(
        for clientID: ClientID = .default,
        default fallback: URL,
        defaults: UserDefaultsService = UserDefaultsService()
    ) -> URL {
        defaults.get(.palDebugSelectedEnvironments)?[clientID.rawValue]?.baseURL ?? fallback
    }
}
