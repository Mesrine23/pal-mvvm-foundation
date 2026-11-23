import Foundation

/// Retries the failures it's told are worth another attempt — by default the
/// transient ones (see ``NetworkError/isRetriable``) — with exponential backoff,
/// respecting task cancellation: a `.cancelled` failure is never retried. Place it
/// outside ``AuthInterceptor`` so auth handling runs fresh on every attempt.
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
    private let shouldRetry: @Sendable (NetworkError) -> Bool

    /// Creates a retry interceptor that retries the failures
    /// ``NetworkError/isRetriable`` accepts.
    /// - Parameters:
    ///   - maxRetries: Additional attempts after the first failure. Defaults to 2.
    ///   - baseDelay: The first backoff delay; doubles per attempt. Defaults to 300 ms.
    public init(maxRetries: Int = 2, baseDelay: Duration = .milliseconds(300)) {
        self.init(maxRetries: maxRetries, baseDelay: baseDelay) { $0.isRetriable }
    }

    /// Creates a retry interceptor that retries the failures the app says are
    /// worth another attempt.
    /// - Parameters:
    ///   - maxRetries: Additional attempts after the first failure. Defaults to 2.
    ///   - baseDelay: The first backoff delay; doubles per attempt. Defaults to 300 ms.
    ///   - shouldRetry: Whether a failure is worth another attempt. It sees the
    ///     whole ``NetworkError`` and is asked only while retries remain. A
    ///     `.cancelled` failure never reaches it and is never retried.
    public init(
        maxRetries: Int = 2,
        baseDelay: Duration = .milliseconds(300),
        shouldRetry: @escaping @Sendable (NetworkError) -> Bool
    ) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.shouldRetry = shouldRetry
    }

    public func intercept(_ request: TransportRequest, next: Next) async throws(NetworkError) -> NetworkResponse {
        let cap = request.options.maxRetries ?? maxRetries
        var attempt = 0
        while true {
            do {
                return try await next(request)
            } catch {
                attempt += 1
                if case .cancelled = error {
                    throw error
                }
                guard attempt <= cap, shouldRetry(error) else {
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
