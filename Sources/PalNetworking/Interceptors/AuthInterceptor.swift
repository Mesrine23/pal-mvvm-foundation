import Foundation

/// Attaches the bearer token to authenticated requests and, on a 401, performs
/// one single-flight refresh via ``TokenProvider`` and retries once with the
/// fresh token. Requests with `requiresAuth == false` pass through untouched —
/// the refresh call itself relies on that to avoid recursion.
public struct AuthInterceptor: Interceptor {

    private let tokenProvider: TokenProvider

    /// Creates an auth interceptor.
    /// - Parameter tokenProvider: The single-flight token owner.
    public init(tokenProvider: TokenProvider) {
        self.tokenProvider = tokenProvider
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
            guard case .unacceptableStatus(401, _, _) = error else {
                throw error
            }
            guard let freshToken = try? await tokenProvider.refresh() else {
                throw error
            }
            authenticated.urlRequest.setValue("Bearer \(freshToken)", forHTTPHeaderField: "Authorization")
            return try await next(authenticated)
        }
    }
}
