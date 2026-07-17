import Foundation
import PalNetworking

/// The outermost interceptor: records every exchange (request start → response/error)
/// with real timing into a ``NetworkLogStore``. Sensitive headers are redacted at
/// capture; bodies are stored as a capped preview only.
struct DebugInspectorInterceptor: Interceptor {

    private let store: NetworkLogStore

    init(store: NetworkLogStore) {
        self.store = store
    }

    func intercept(_ request: TransportRequest, next: Next) async throws(NetworkError) -> NetworkResponse {
        let clock = ContinuousClock()
        let start = clock.now
        let method = request.urlRequest.httpMethod ?? "GET"
        let url = request.urlRequest.url?.absoluteString ?? "<no url>"
        let headers = Self.redact(request.urlRequest.allHTTPHeaderFields ?? [:])
        let requestBody = Self.preview(request.urlRequest.httpBody ?? Data())

        do {
            let response = try await next(request)
            await store.record(NetworkLogEntry(
                method: method,
                url: url,
                requestHeaders: headers,
                requestBodyPreview: requestBody,
                statusCode: response.statusCode,
                duration: clock.now - start,
                responseBodyPreview: Self.preview(response.data),
                errorDescription: nil
            ))
            return response
        } catch {
            await store.record(NetworkLogEntry(
                method: method,
                url: url,
                requestHeaders: headers,
                requestBodyPreview: requestBody,
                statusCode: Self.statusCode(of: error),
                duration: clock.now - start,
                responseBodyPreview: nil,
                errorDescription: String(describing: error)
            ))
            throw error
        }
    }

    private static let sensitiveKeys: Set<String> = [
        "authorization", "cookie", "set-cookie", "x-api-key", "api-key", "proxy-authorization",
    ]

    private static func redact(_ headers: [String: String]) -> [String: String] {
        var out: [String: String] = [:]
        for (key, value) in headers {
            out[key] = sensitiveKeys.contains(key.lowercased()) ? "<redacted>" : value
        }
        return out
    }

    private static func preview(_ data: Data, limit: Int = 20_000) -> String? {
        guard !data.isEmpty else { return nil }
        let text = String(decoding: data.prefix(limit), as: UTF8.self)
        return text.isEmpty ? nil : text
    }

    private static func statusCode(of error: NetworkError) -> Int? {
        if case .unacceptableStatus(let code, _, _) = error { return code }
        return nil
    }
}
