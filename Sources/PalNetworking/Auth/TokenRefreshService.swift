/// Performs the actual token-refresh call. **App-provided** — only the app knows
/// its refresh endpoint and token DTOs. The implementation must send the request
/// with `RequestOptions(requiresAuth: false)` to keep it outside ``AuthInterceptor``.
public protocol TokenRefreshService: Sendable {

    /// Exchanges a refresh token for a fresh token pair.
    /// - Parameter refreshToken: The current refresh token.
    /// - Returns: The new token pair.
    /// - Throws: ``TransientRefreshFailure`` when the failure shouldn't end the
    ///   session, which ``TokenProvider`` then keeps. Any other error when the
    ///   exchange fails; ``TokenProvider`` treats it as a dead session.
    func refresh(using refreshToken: String) async throws -> AuthTokens
}
