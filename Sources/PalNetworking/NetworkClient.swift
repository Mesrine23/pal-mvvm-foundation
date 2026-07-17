/// Sends typed requests and returns decoded responses. Repositories depend on
/// this protocol; ``HTTPClient`` is the production implementation, and tests
/// substitute a mock returning canned values.
public protocol NetworkClient: Sendable {

    /// Executes the request and decodes the response into the request's `Response` type.
    /// - Parameter request: The typed request to send.
    /// - Returns: The decoded response value.
    /// - Throws: ``NetworkError`` describing exactly what went wrong.
    func send<Response>(_ request: Request<Response>) async throws(NetworkError) -> Response

    /// Executes the request and returns the decoded value TOGETHER with the raw
    /// ``NetworkResponse`` — for call sites that need the status code or response
    /// headers (`ETag`, `Location`, rate-limit headers) without writing an interceptor.
    /// - Parameter request: The typed request to send.
    /// - Returns: The decoded value and the validated transport response.
    /// - Throws: ``NetworkError`` describing exactly what went wrong.
    func sendWithResponse<Response>(
        _ request: Request<Response>
    ) async throws(NetworkError) -> (value: Response, response: NetworkResponse)
}

public extension NetworkClient {

    /// Default conformance so existing mocks keep compiling: forwards to
    /// ``send(_:)`` and returns a placeholder ``NetworkResponse`` (status 0, no
    /// headers). Conformances backed by a real transport — like ``HTTPClient`` —
    /// implement this properly; override it in mocks that need to stub metadata.
    func sendWithResponse<Response>(
        _ request: Request<Response>
    ) async throws(NetworkError) -> (value: Response, response: NetworkResponse) {
        (try await send(request), NetworkResponse(statusCode: 0))
    }
}
