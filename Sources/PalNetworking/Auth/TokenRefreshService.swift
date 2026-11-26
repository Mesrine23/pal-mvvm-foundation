/// Performs the actual token-refresh call. **App-provided** — only the app knows
/// its refresh endpoint, its token DTOs, and which of its failures are temporary.
///
/// Send the request with `RequestOptions(requiresAuth: false)`, so it passes
/// ``AuthInterceptor`` untouched — a client of its own, without
/// `AuthInterceptor`, is the simplest wiring. Give it a short `timeout`, and
/// `maxRetries: 0` when refresh tokens rotate: a retry after a lost answer could
/// send a refresh token that's already spent.
public protocol TokenRefreshService: Sendable {

    /// Exchanges a refresh token for a fresh token pair.
    /// - Parameter refreshToken: The current refresh token.
    /// - Returns: The new token pair.
    /// - Throws: ``TransientRefreshFailure`` when the failure shouldn't end the
    ///   session, which ``TokenProvider`` then keeps. Any other error ends the
    ///   session, as for a rejected refresh token.
    func refresh(using refreshToken: String) async throws -> AuthTokens
}
