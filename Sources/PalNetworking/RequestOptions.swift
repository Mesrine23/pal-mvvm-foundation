import Foundation

/// Per-request flags that travel through the interceptor chain alongside the `URLRequest`.
public struct RequestOptions: Sendable {

    /// Whether ``AuthInterceptor`` should attach a token and handle 401s.
    /// Set `false` on the token-refresh request itself to avoid recursion.
    public var requiresAuth: Bool

    /// Free-form flags for app- or tooling-specific interceptors.
    public var flags: [String: String]

    /// This request's own deadline, applied to `URLRequest.timeoutInterval` —
    /// so a type-ahead search and a report export can share one client.
    /// `nil` uses the session's configured timeout.
    public var timeout: Duration?

    /// Overrides ``RetryInterceptor``'s retry cap for this request; `0` means
    /// never retry (the right call for non-idempotent POSTs). `nil` uses the
    /// interceptor's own cap.
    public var maxRetries: Int?

    /// How 3xx responses are handled. Defaults to ``RedirectPolicy/follow``.
    public var redirectPolicy: RedirectPolicy

    /// The file to upload via an upload task, set by ``HTTPBody/file(_:contentType:)``.
    public internal(set) var uploadFileURL: URL?

    /// Creates request options.
    /// - Parameters:
    ///   - requiresAuth: Whether the request carries authentication. Defaults to `true`.
    ///   - flags: Free-form flags for custom interceptors. Defaults to empty.
    ///   - timeout: The per-request deadline. Defaults to `nil` (session timeout).
    ///   - maxRetries: The per-request retry-cap override. Defaults to `nil`.
    ///   - redirectPolicy: How 3xx responses are handled. Defaults to `.follow`.
    public init(
        requiresAuth: Bool = true,
        flags: [String: String] = [:],
        timeout: Duration? = nil,
        maxRetries: Int? = nil,
        redirectPolicy: RedirectPolicy = .follow
    ) {
        self.requiresAuth = requiresAuth
        self.flags = flags
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.redirectPolicy = redirectPolicy
        self.uploadFileURL = nil
    }
}
