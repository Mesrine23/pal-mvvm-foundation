import Foundation

/// Attaches the bearer token to authenticated requests and, on a token rejection
/// (by default any 401; see ``init(tokenProvider:isTokenRejection:)``), performs
/// one single-flight refresh via ``TokenProvider`` and retries once with the
/// fresh token. Requests with `requiresAuth == false` pass through untouched —
/// the refresh call itself relies on that to avoid recursion.
public struct AuthInterceptor: Interceptor {

    private let tokenProvider: TokenProvider
    private let isTokenRejection: @Sendable (NetworkError) -> Bool

    /// Creates an auth interceptor that takes any 401 as a token rejection.
    /// - Parameter tokenProvider: The single-flight token owner.
    public init(tokenProvider: TokenProvider) {
        self.init(tokenProvider: tokenProvider) { $0.statusCode == 401 }
    }

    /// Creates an auth interceptor that refreshes only for the failures the app
    /// recognises as a rejected access token.
    /// - Parameters:
    ///   - tokenProvider: The single-flight token owner.
    ///   - isTokenRejection: Whether a failed authenticated call means its access
    ///     token was rejected. It sees the whole ``NetworkError``: status, headers
    ///     and body. Failures it doesn't accept reach the caller unchanged.
    public init(tokenProvider: TokenProvider, isTokenRejection: @escaping @Sendable (NetworkError) -> Bool) {
        self.tokenProvider = tokenProvider
        self.isTokenRejection = isTokenRejection
    }

    public func intercept(_ request: TransportRequest, next: Next) async throws(NetworkError) -> NetworkResponse {
        guard request.options.requiresAuth else {
            return try await next(request)
        }

        var authenticated = request
        if let token = await tokenProvider.currentToken() {
            authenticated.urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            return try await next(authenticated)
        } catch {
            guard isTokenRejection(error) else {
                throw error
            }
            switch await tokenProvider.refreshOutcome() {
            case .token(let freshToken):
                authenticated.urlRequest.setValue("Bearer \(freshToken)", forHTTPHeaderField: "Authorization")
                return try await next(authenticated)
            case .ended:
                throw error
            case .kept(let networkError):
                throw networkError
            }
        }
    }
}
