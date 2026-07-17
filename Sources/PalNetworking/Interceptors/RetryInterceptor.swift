import Foundation

/// Retries transient failures (see ``NetworkError/isRetriable``) with exponential
/// backoff, respecting task cancellation. Place it outside ``AuthInterceptor`` so
/// auth handling runs fresh on every attempt.
///
/// Per request, ``RequestOptions/maxRetries`` overrides the cap (`0` = never
/// retry). When an error carries a `Retry-After` hint (429/503), the server's
/// delay is honored instead of the backoff, capped at 30 seconds.
///
/// The transport itself may transparently retry dropped connections before this
/// interceptor sees anything, so servers can observe more physical attempts
/// than the cap — the cap governs *logical* attempts.
public struct RetryInterceptor: Interceptor {

    private static let maxServerAdvisedDelay: Duration = .seconds(30)

    private let maxRetries: Int
    private let baseDelay: Duration

    /// Creates a retry interceptor.
    /// - Parameters:
    ///   - maxRetries: Additional attempts after the first failure. Defaults to 2.
    ///   - baseDelay: The first backoff delay; doubles per attempt. Defaults to 300 ms.
    public init(maxRetries: Int = 2, baseDelay: Duration = .milliseconds(300)) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
    }

    public func intercept(_ request: TransportRequest, next: Next) async throws(NetworkError) -> NetworkResponse {
        let cap = request.options.maxRetries ?? maxRetries
        var attempt = 0
        while true {
            do {
                return try await next(request)
            } catch {
                attempt += 1
                guard error.isRetriable, attempt <= cap else {
                    throw error
                }
                let backoff = baseDelay * (1 << (attempt - 1))
                let delay = error.retryAfter.map { min($0, Self.maxServerAdvisedDelay) } ?? backoff
                do {
                    try await Task.sleep(for: delay)
                } catch {
                    throw NetworkError.cancelled
                }
            }
        }
    }
}
