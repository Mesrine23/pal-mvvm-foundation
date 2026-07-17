import Foundation

/// A typed HTTP request whose generic parameter carries the expected response type
/// through to the call site.
///
/// Apps define endpoints as one-line static factories in their Data layer:
/// ```swift
/// extension Request {
///     static func user(id: Int) -> Request<UserDTO> {
///         Request(path: "/users/\(id)")
///     }
///     static func createUser(_ dto: CreateUserDTO) -> Request<UserDTO> {
///         Request(method: .post, path: "/users", body: .json(dto))
///     }
/// }
///
/// let user = try await client.send(.user(id: 1))
/// ```
public struct Request<Response: Decodable & Sendable>: Sendable {

    /// The HTTP method. Defaults to `.get`.
    public var method: HTTPMethod

    /// The path appended to the client's base URL, e.g. `"/users/1"`.
    public var path: String

    /// Query items appended to the URL.
    public var query: [URLQueryItem]

    /// Additional headers for this request.
    public var headers: [String: String]

    /// The request payload.
    public var body: HTTPBody?

    /// Per-request flags carried through the interceptor chain.
    public var options: RequestOptions

    /// Creates a typed request.
    /// - Parameters:
    ///   - method: The HTTP method. Defaults to `.get`.
    ///   - path: The path appended to the client's base URL.
    ///   - query: Query items. Defaults to empty.
    ///   - headers: Additional headers. Defaults to empty.
    ///   - body: The payload. Defaults to `nil`.
    ///   - options: Per-request flags. Defaults to ``RequestOptions/init(requiresAuth:flags:)`` defaults.
    public init(
        method: HTTPMethod = .get,
        path: String,
        query: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: HTTPBody? = nil,
        options: RequestOptions = RequestOptions()
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.headers = headers
        self.body = body
        self.options = options
    }

    /// Creates a typed request with dictionary-literal query syntax. Order is
    /// preserved (`KeyValuePairs`, unlike `Dictionary`), so requests stay
    /// byte-deterministic:
    /// ```swift
    /// Request<SearchDTO>(path: "/search", query: ["q": text, "limit": "20"])
    /// ```
    /// - Parameters:
    ///   - method: The HTTP method. Defaults to `.get`.
    ///   - path: The path appended to the client's base URL.
    ///   - query: Query pairs in literal order.
    ///   - headers: Additional headers. Defaults to empty.
    ///   - body: The payload. Defaults to `nil`.
    ///   - options: Per-request flags. Defaults to the standard options.
    public init(
        method: HTTPMethod = .get,
        path: String,
        query: KeyValuePairs<String, String>,
        headers: [String: String] = [:],
        body: HTTPBody? = nil,
        options: RequestOptions = RequestOptions()
    ) {
        self.init(
            method: method,
            path: path,
            query: query.map { URLQueryItem(name: $0.key, value: $0.value) },
            headers: headers,
            body: body,
            options: options
        )
    }
}
