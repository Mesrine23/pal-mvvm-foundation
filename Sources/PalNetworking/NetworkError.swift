import Foundation

/// Every failure the networking layer can produce. Thrown as a typed error by
/// ``NetworkClient/send(_:)`` so callers handle an exhaustive, known set.
///
/// Repositories map this to domain errors; it never reaches Presentation directly.
public enum NetworkError: Error, Sendable {

    /// The `URLRequest` could not be built (bad base URL, path, or body encoding).
    case invalidRequest

    /// The transport layer failed: offline, timeout, TLS, DNS.
    case transport(URLError)

    /// The server answered outside 200–299; carries the raw body for on-demand
    /// decoding via ``serverError(as:decoder:)`` and the response headers
    /// (`Retry-After`, `Location`, rate limits) via ``responseHeaders``.
    case unacceptableStatus(code: Int, data: Data, headers: [String: String])

    /// The 2xx body could not be decoded into the request's `Response` type.
    case decoding(DecodingError)

    /// The request was cancelled. Never surface this to users.
    case cancelled
}

public extension NetworkError {

    /// Decodes the server's error body into the given type, when this error is
    /// ``unacceptableStatus(code:data:headers:)``.
    /// - Parameters:
    ///   - type: The backend error payload type.
    ///   - decoder: The decoder to use. Defaults to a fresh `JSONDecoder`.
    /// - Returns: The decoded payload, or `nil` when unavailable or undecodable.
    func serverError<E: Decodable>(as type: E.Type, decoder: JSONDecoder = JSONDecoder()) -> E? {
        guard case .unacceptableStatus(_, let data, _) = self else { return nil }
        return try? decoder.decode(type, from: data)
    }

    /// Whether retrying the request could plausibly succeed: transient transport
    /// failures, 5xx server responses, and 429 rate limiting (whose `Retry-After`
    /// hint ``RetryInterceptor`` honors via ``retryAfter``).
    var isRetriable: Bool {
        switch self {
        case .transport(let urlError):
            [.timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed]
                .contains(urlError.code)
        case .unacceptableStatus(let code, _, _):
            (500...599).contains(code) || code == 429
        case .invalidRequest, .decoding, .cancelled:
            false
        }
    }

    /// The HTTP status of an ``unacceptableStatus(code:data:headers:)``, else `nil`.
    var statusCode: Int? {
        guard case .unacceptableStatus(let code, _, _) = self else { return nil }
        return code
    }

    /// The underlying `URLError` of a ``transport(_:)``, else `nil`.
    var urlError: URLError? {
        guard case .transport(let urlError) = self else { return nil }
        return urlError
    }

    /// The response headers of an ``unacceptableStatus(code:data:headers:)``, else `nil`.
    var responseHeaders: [String: String]? {
        guard case .unacceptableStatus(_, _, let headers) = self else { return nil }
        return headers
    }

    /// The server's `Retry-After` hint as a duration, when present on an error
    /// response (integer-seconds form only; the HTTP-date form is not parsed).
    var retryAfter: Duration? {
        guard let headers = responseHeaders,
              let value = headers.first(where: { $0.key.caseInsensitiveCompare("Retry-After") == .orderedSame })?.value,
              let seconds = Int(value.trimmingCharacters(in: .whitespaces)),
              seconds >= 0 else {
            return nil
        }
        return .seconds(seconds)
    }
}

extension NetworkError: CustomStringConvertible {

    /// A compact, redaction-safe rendering: header VALUES never appear, so
    /// `String(describing:)` in log lines (``LoggingInterceptor`` logs errors
    /// with public privacy) cannot leak `Set-Cookie`, auth echoes, or the like.
    public var description: String {
        switch self {
        case .invalidRequest:
            "invalidRequest"
        case .transport(let urlError):
            "transport(URLError \(urlError.code.rawValue))"
        case .unacceptableStatus(let code, let data, let headers):
            "unacceptableStatus(\(code), \(data.count) body bytes, \(headers.count) headers)"
        case .decoding:
            "decoding"
        case .cancelled:
            "cancelled"
        }
    }
}
