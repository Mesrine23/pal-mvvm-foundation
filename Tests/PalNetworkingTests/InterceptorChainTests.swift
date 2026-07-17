import Foundation
import Testing
@testable import PalNetworking

actor CallLog {

    private(set) var entries: [String] = []

    func append(_ entry: String) {
        entries.append(entry)
    }
}

struct RecordingInterceptor: Interceptor {

    let id: String
    let log: CallLog

    func intercept(_ request: TransportRequest, next: Next) async throws(NetworkError) -> NetworkResponse {
        await log.append("\(id):before")
        let response = try await next(request)
        await log.append("\(id):after")
        return response
    }
}

struct ShortCircuitInterceptor: Interceptor {

    func intercept(_ request: TransportRequest, next: Next) async throws(NetworkError) -> NetworkResponse {
        NetworkResponse(statusCode: 299)
    }
}

actor TransportSpy {

    private(set) var requests: [TransportRequest] = []

    func record(_ request: TransportRequest) -> Int {
        requests.append(request)
        return requests.count
    }

    func authorizationHeader(ofCall index: Int) -> String? {
        guard requests.indices.contains(index) else { return nil }
        return requests[index].urlRequest.value(forHTTPHeaderField: "Authorization")
    }
}

@Suite("Interceptor chain")
struct InterceptorChainTests {

    private func makeRequest() throws -> TransportRequest {
        let url = try #require(URL(string: "https://api.example.test/users"))
        return TransportRequest(urlRequest: URLRequest(url: url), options: RequestOptions())
    }

    @Test("Interceptors run outer→inner on the way down, inner→outer on the way up")
    func chainPreservesOrder() async throws {
        let log = CallLog()
        let transport: Next = { _ throws(NetworkError) in
            await log.append("transport")
            return NetworkResponse(statusCode: 200)
        }
        let chain = InterceptorChain(
            interceptors: [RecordingInterceptor(id: "A", log: log), RecordingInterceptor(id: "B", log: log)],
            transport: transport
        )

        _ = try await chain.execute(makeRequest())

        #expect(await log.entries == ["A:before", "B:before", "transport", "B:after", "A:after"])
    }

    @Test("A short-circuiting interceptor prevents the transport from running")
    func shortCircuitSkipsTransport() async throws {
        let log = CallLog()
        let transport: Next = { _ throws(NetworkError) in
            await log.append("transport")
            return NetworkResponse(statusCode: 200)
        }
        let chain = InterceptorChain(
            interceptors: [RecordingInterceptor(id: "outer", log: log), ShortCircuitInterceptor()],
            transport: transport
        )

        let response = try await chain.execute(makeRequest())

        #expect(response.statusCode == 299)
        #expect(await log.entries == ["outer:before", "outer:after"])
    }

    @Test("Typed errors propagate through the chain unchanged")
    func typedErrorsPropagate() async throws {
        let transport: Next = { _ throws(NetworkError) in
            throw NetworkError.transport(URLError(.timedOut))
        }
        let chain = InterceptorChain(
            interceptors: [RecordingInterceptor(id: "A", log: CallLog())],
            transport: transport
        )

        let request = try makeRequest()
        do {
            _ = try await chain.execute(request)
            Issue.record("Expected a transport error")
        } catch {
            guard case .transport(let urlError) = error else {
                Issue.record("Expected .transport, got \(error)")
                return
            }
            #expect(urlError.code == .timedOut)
        }
    }

    @Test("RetryInterceptor retries retriable failures with backoff, then succeeds")
    func retryRecoversFromTransientFailures() async throws {
        let spy = TransportSpy()
        let transport: Next = { request throws(NetworkError) in
            let call = await spy.record(request)
            guard call >= 3 else {
                throw NetworkError.transport(URLError(.timedOut))
            }
            return NetworkResponse(statusCode: 200)
        }
        let chain = InterceptorChain(
            interceptors: [RetryInterceptor(maxRetries: 2, baseDelay: .milliseconds(1))],
            transport: transport
        )

        let response = try await chain.execute(makeRequest())

        #expect(response.statusCode == 200)
        #expect(await spy.requests.count == 3)
    }

    @Test("RetryInterceptor does NOT retry non-retriable failures")
    func retrySkipsNonRetriableFailures() async throws {
        let spy = TransportSpy()
        let transport: Next = { request throws(NetworkError) in
            _ = await spy.record(request)
            throw NetworkError.unacceptableStatus(code: 400, data: Data(), headers: [:])
        }
        let chain = InterceptorChain(
            interceptors: [RetryInterceptor(maxRetries: 2, baseDelay: .milliseconds(1))],
            transport: transport
        )

        let request = try makeRequest()
        do {
            _ = try await chain.execute(request)
            Issue.record("Expected a 400 error")
        } catch {
            guard case .unacceptableStatus(let code, _, _) = error else {
                Issue.record("Expected .unacceptableStatus, got \(error)")
                return
            }
            #expect(code == 400)
        }
        #expect(await spy.requests.count == 1)
    }

    @Test("AuthInterceptor: 401 → one refresh → retried request carries the fresh token")
    func authInterceptorRefreshesAndRetriesOn401() async throws {
        let refresher = CountingRefresher(delay: .milliseconds(5))
        let provider = TokenProvider(
            store: InMemoryTokenStore(tokens: AuthTokens(accessToken: "stale", refreshToken: "valid")),
            refresher: refresher
        )
        let spy = TransportSpy()
        let transport: Next = { request throws(NetworkError) in
            let call = await spy.record(request)
            guard call > 1 else {
                throw NetworkError.unacceptableStatus(code: 401, data: Data(), headers: [:])
            }
            return NetworkResponse(statusCode: 200)
        }
        let chain = InterceptorChain(
            interceptors: [AuthInterceptor(tokenProvider: provider)],
            transport: transport
        )

        let response = try await chain.execute(makeRequest())

        #expect(response.statusCode == 200)
        #expect(await spy.requests.count == 2)
        #expect(await refresher.refreshCount == 1)
        #expect(await spy.authorizationHeader(ofCall: 0) == "Bearer stale")
        #expect(await spy.authorizationHeader(ofCall: 1) == "Bearer fresh-1")
    }

    @Test("AuthInterceptor leaves requiresAuth=false requests untouched")
    func authInterceptorSkipsUnauthenticatedRequests() async throws {
        let provider = TokenProvider(
            store: InMemoryTokenStore(tokens: AuthTokens(accessToken: "stale", refreshToken: "valid")),
            refresher: CountingRefresher()
        )
        let spy = TransportSpy()
        let transport: Next = { request throws(NetworkError) in
            _ = await spy.record(request)
            return NetworkResponse(statusCode: 200)
        }
        let chain = InterceptorChain(
            interceptors: [AuthInterceptor(tokenProvider: provider)],
            transport: transport
        )

        let url = try #require(URL(string: "https://api.example.test/auth/refresh"))
        let request = TransportRequest(
            urlRequest: URLRequest(url: url),
            options: RequestOptions(requiresAuth: false)
        )
        _ = try await chain.execute(request)

        #expect(await spy.authorizationHeader(ofCall: 0) == nil)
    }
}
