/// The error a ``TokenRefreshService`` throws when a refresh failed for a reason
/// that shouldn't end the session. Which failures those are is the app's call:
/// a timeout, say, or an outage of its token endpoint. A dead refresh token can
/// come back as a 5xx too, so ``NetworkError/isRetriable`` alone can't tell.
///
/// ``TokenProvider`` then keeps the stored tokens and emits no event. The calls
/// waiting on the refresh fail with ``networkError`` instead of their token
/// rejection, and a direct ``TokenProvider/refresh()`` throws
/// ``AuthError/refreshFailed`` — unless ``TokenProvider/logOut()`` ended the
/// session meanwhile, which drops the failure. Any other error the refresher
/// throws ends the session.
///
/// A ``RetryInterceptor`` outside ``AuthInterceptor`` retries a call that fails
/// with a retriable ``networkError``, and each attempt tries the refresh again;
/// ``retryAfter`` spares the token endpoint those attempts.
public struct TransientRefreshFailure: Error, Sendable {

    /// The error the calls waiting on the refresh fail with.
    public let networkError: NetworkError

    /// How long to hold off before the next refresh attempt with the same refresh
    /// token. Until it passes, ``TokenProvider`` answers later token rejections with
    /// ``networkError``, and a direct ``TokenProvider/refresh()`` with
    /// ``AuthError/refreshFailed``, without calling the refresher. Another refresh
    /// token, such as a new login's, isn't held, and ``TokenProvider/logOut()``
    /// ends the period early. `nil`, zero or less: the next rejection tries again.
    ///
    /// The server's `Retry-After` suits a 503 (``NetworkError/retryAfter``), and
    /// about two seconds a timeout: that covers ``RetryInterceptor``'s default
    /// backoff. Leave it `nil` when every attempt should try the refresh.
    public let retryAfter: Duration?

    /// Creates the failure.
    /// - Parameters:
    ///   - networkError: The error the calls waiting on the refresh fail with.
    ///   - retryAfter: How long to hold off before the next attempt with the same
    ///     refresh token. Defaults to `nil`, which holds nothing.
    public init(_ networkError: NetworkError, retryAfter: Duration? = nil) {
        self.networkError = networkError
        self.retryAfter = retryAfter
    }
}
