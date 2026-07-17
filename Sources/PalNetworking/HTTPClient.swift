import Foundation

/// The production ``NetworkClient``: builds `URLRequest`s from typed ``Request``s,
/// runs them through the interceptor chain, validates the status, and decodes.
///
/// Immutable after `init` and safe to register as a single shared instance in the
/// app's composition root. Special-cased responses: `Data` and `String` bypass JSON
/// decoding (file/PDF endpoints), and ``EmptyResponse`` accepts empty bodies.
public final class HTTPClient: NetworkClient {

    private let baseURLProvider: @Sendable () -> URL
    private let session: URLSession
    private let interceptors: [any Interceptor]
    private let makeDecoder: @Sendable () -> JSONDecoder
    private let makeEncoder: @Sendable () -> JSONEncoder

    /// Creates a client whose base URL is resolved per request.
    /// - Parameters:
    ///   - baseURLProvider: Returns the base URL request paths are appended to,
    ///     evaluated on every request — so runtime environment switching takes
    ///     effect without rebuilding the client.
    ///   - session: The underlying session. Defaults to `.shared`.
    ///   - interceptors: The middleware chain, outermost first. Defaults to none.
    ///   - makeDecoder: Produces the decoder for response bodies. Defaults to a plain `JSONDecoder`.
    ///   - makeEncoder: Produces the encoder for ``HTTPBody/json(_:)`` bodies. Defaults to a plain `JSONEncoder`.
    public init(
        baseURLProvider: @escaping @Sendable () -> URL,
        session: URLSession = .shared,
        interceptors: [any Interceptor] = [],
        makeDecoder: @escaping @Sendable () -> JSONDecoder = JSONDecoder.init,
        makeEncoder: @escaping @Sendable () -> JSONEncoder = JSONEncoder.init
    ) {
        self.baseURLProvider = baseURLProvider
        self.session = session
        self.interceptors = interceptors
        self.makeDecoder = makeDecoder
        self.makeEncoder = makeEncoder
    }

    /// Creates a client with a fixed base URL.
    /// - Parameters:
    ///   - baseURL: The base URL request paths are appended to.
    ///   - session: The underlying session. Defaults to `.shared`.
    ///   - interceptors: The middleware chain, outermost first. Defaults to none.
    ///   - makeDecoder: Produces the decoder for response bodies. Defaults to a plain `JSONDecoder`.
    ///   - makeEncoder: Produces the encoder for ``HTTPBody/json(_:)`` bodies. Defaults to a plain `JSONEncoder`.
    public convenience init(
        baseURL: URL,
        session: URLSession = .shared,
        interceptors: [any Interceptor] = [],
        makeDecoder: @escaping @Sendable () -> JSONDecoder = JSONDecoder.init,
        makeEncoder: @escaping @Sendable () -> JSONEncoder = JSONEncoder.init
    ) {
        self.init(
            baseURLProvider: { baseURL },
            session: session,
            interceptors: interceptors,
            makeDecoder: makeDecoder,
            makeEncoder: makeEncoder
        )
    }

    public func send<Response>(_ request: Request<Response>) async throws(NetworkError) -> Response {
        try await sendWithResponse(request).value
    }

    public func sendWithResponse<Response>(
        _ request: Request<Response>
    ) async throws(NetworkError) -> (value: Response, response: NetworkResponse) {
        let transportRequest = try makeTransportRequest(from: request)
        let chain = InterceptorChain(interceptors: interceptors, transport: Self.makeTransport(session: session))
        let response = try await chain.execute(transportRequest)
        return (try decode(response.data), response)
    }

    // MARK: - Request building

    private func makeTransportRequest<Response>(
        from request: Request<Response>
    ) throws(NetworkError) -> TransportRequest {
        guard let url = makeURL(path: request.path, query: request.query) else {
            throw .invalidRequest
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        if let timeout = request.options.timeout {
            urlRequest.timeoutInterval = Self.timeInterval(from: timeout)
        }
        for (field, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }

        var options = request.options
        switch request.body {
        case nil:
            break
        case .json(let value):
            guard let data = try? makeEncoder().encode(value) else {
                throw .invalidRequest
            }
            urlRequest.httpBody = data
            setContentTypeIfMissing("application/json", on: &urlRequest)
        case .data(let data, let contentType):
            urlRequest.httpBody = data
            setContentTypeIfMissing(contentType, on: &urlRequest)
        case .multipart(let parts):
            let boundary = "pal.boundary.\(UUID().uuidString)"
            urlRequest.httpBody = Self.multipartBody(parts: parts, boundary: boundary)
            setContentTypeIfMissing("multipart/form-data; boundary=\(boundary)", on: &urlRequest)
        case .file(let fileURL, let contentType):
            options.uploadFileURL = fileURL
            setContentTypeIfMissing(contentType, on: &urlRequest)
        }

        return TransportRequest(urlRequest: urlRequest, options: options)
    }

    private func makeURL(path: String, query: [URLQueryItem]) -> URL? {
        let url = baseURLProvider().appending(path: path)
        guard !query.isEmpty else { return url }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        components.queryItems = (components.queryItems ?? []) + query
        // RFC 3986 permits a literal `+` in queries, so URLComponents leaves it —
        // but real-world servers decode queries as form-urlencoded, where `+`
        // means space. Emit `%2B` so `a+b` survives the wire (idempotent: an
        // already-encoded plus is `%2B` and contains no literal `+`).
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        return components.url
    }

    private static func timeInterval(from duration: Duration) -> TimeInterval {
        let components = duration.components
        return TimeInterval(components.seconds) + TimeInterval(components.attoseconds) / 1e18
    }

    private func setContentTypeIfMissing(_ contentType: String, on urlRequest: inout URLRequest) {
        guard urlRequest.value(forHTTPHeaderField: "Content-Type") == nil else { return }
        urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
    }

    private static func multipartBody(parts: [MultipartPart], boundary: String) -> Data {
        var body = Data()
        for part in parts {
            var disposition = "form-data; name=\"\(part.name)\""
            if let filename = part.filename {
                disposition += "; filename=\"\(filename)\""
            }
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: \(disposition)\r\n".utf8))
            body.append(Data("Content-Type: \(part.mimeType)\r\n\r\n".utf8))
            body.append(part.data)
            body.append(Data("\r\n".utf8))
        }
        body.append(Data("--\(boundary)--\r\n".utf8))
        return body
    }

    // MARK: - Transport

    private static func makeTransport(session: URLSession) -> Next {
        { request throws(NetworkError) in
            let data: Data
            let urlResponse: URLResponse
            let delegate: URLSessionTaskDelegate? = request.options.redirectPolicy == .deny ? RedirectDenier() : nil
            do {
                if let fileURL = request.options.uploadFileURL {
                    (data, urlResponse) = try await session.upload(for: request.urlRequest, fromFile: fileURL, delegate: delegate)
                } else {
                    (data, urlResponse) = try await session.data(for: request.urlRequest, delegate: delegate)
                }
            } catch let urlError as URLError where urlError.code == .cancelled {
                throw NetworkError.cancelled
            } catch let urlError as URLError {
                throw NetworkError.transport(urlError)
            } catch is CancellationError {
                throw NetworkError.cancelled
            } catch {
                throw NetworkError.transport(URLError(.unknown))
            }

            guard let http = urlResponse as? HTTPURLResponse else {
                throw NetworkError.transport(URLError(.badServerResponse))
            }
            var headers: [String: String] = [:]
            for (field, value) in http.allHeaderFields {
                if let field = field as? String, let value = value as? String {
                    headers[field] = value
                }
            }
            guard (200...299).contains(http.statusCode) else {
                throw NetworkError.unacceptableStatus(code: http.statusCode, data: data, headers: headers)
            }
            return NetworkResponse(statusCode: http.statusCode, headers: headers, data: data)
        }
    }

    // MARK: - Decoding

    private func decode<Response: Decodable & Sendable>(_ data: Data) throws(NetworkError) -> Response {
        if Response.self == Data.self, let value = data as? Response {
            return value
        }
        if Response.self == String.self,
           let string = String(data: data, encoding: .utf8),
           let value = string as? Response {
            return value
        }
        if data.isEmpty, Response.self == EmptyResponse.self, let value = EmptyResponse() as? Response {
            return value
        }
        do {
            return try makeDecoder().decode(Response.self, from: data)
        } catch let error as DecodingError {
            throw .decoding(error)
        } catch {
            throw .decoding(.dataCorrupted(.init(codingPath: [], debugDescription: "Response body could not be decoded")))
        }
    }
}
