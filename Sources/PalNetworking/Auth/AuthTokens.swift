import Foundation

/// The token pair (plus optional expiry) produced by login and refresh flows.
/// `Codable` so stores can persist it directly.
public struct AuthTokens: Codable, Sendable, Equatable {

    /// The bearer token attached to authenticated requests.
    public let accessToken: String

    /// The long-lived token used to obtain fresh access tokens.
    public let refreshToken: String

    /// When the access token expires, when the backend provides it. Stored for the
    /// app's own use: ``TokenProvider`` never reads it, so nothing refreshes ahead
    /// of expiry.
    public let expiresAt: Date?

    /// Creates a token pair.
    /// - Parameters:
    ///   - accessToken: The bearer token for authenticated requests.
    ///   - refreshToken: The token used to refresh the pair.
    ///   - expiresAt: The access token's expiry. Defaults to `nil`.
    public init(accessToken: String, refreshToken: String, expiresAt: Date? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }
}
