import Foundation
import PalNetworking

/// Short-circuits the chain with a stubbed response when an enabled mock matches.
/// Placed inside the inspector, so mocked exchanges still appear in the Logs tab.
///
/// It validates the mock's status **itself** — non-2xx throws `.unacceptableStatus`
/// (it sits above the transport's validation) — so a custom status works uniformly
/// and the app's real decoder still runs on the stubbed body.
struct MockInterceptor: Interceptor {

    private let registry: MockRegistry

    init(registry: MockRegistry) {
        self.registry = registry
    }

    func intercept(_ request: TransportRequest, next: Next) async throws(NetworkError) -> NetworkResponse {
        let method = request.urlRequest.httpMethod ?? "GET"
        guard let mock = await registry.match(method: method, url: request.urlRequest.url) else {
            return try await next(request)
        }
        guard (200...299).contains(mock.statusCode) else {
            throw NetworkError.unacceptableStatus(code: mock.statusCode, data: mock.body, headers: mock.headers)
        }
        return NetworkResponse(statusCode: mock.statusCode, headers: mock.headers, data: mock.body)
    }
}
