import Foundation
import Testing
@testable import PalNetworking

private actor AttemptCounter {

    private(set) var attempts = 0

    func next() -> Int {
        attempts += 1
        return attempts
    }
}

@Suite("RetryInterceptor")
struct RetryInterceptorTests {

    private func makeRequest(options: RequestOptions = RequestOptions()) throws -> TransportRequest {
        let url = try #require(URL(string: "https://api.example.test/retry"))
        return TransportRequest(urlRequest: URLRequest(url: url), options: options)
    }

    private func alwaysFailing(_ counter: AttemptCounter, status: Int = 500, headers: [String: String] = [:]) -> Next {
        { _ throws(NetworkError) in
            _ = await counter.next()
            throw NetworkError.unacceptableStatus(code: status, data: Data(), headers: headers)
        }
    }

    @Test("A per-request maxRetries of 0 disables retries entirely")
    func perRequestZeroDisablesRetries() async throws {
        let counter = AttemptCounter()
        let chain = InterceptorChain(
            interceptors: [RetryInterceptor(maxRetries: 2, baseDelay: .milliseconds(1))],
            transport: alwaysFailing(counter)
        )

        await #expect(throws: NetworkError.self) {
            _ = try await chain.execute(makeRequest(options: RequestOptions(maxRetries: 0)))
        }
        #expect(await counter.attempts == 1)
    }

    @Test("A per-request maxRetries raises the interceptor's own cap")
    func perRequestOverrideRaisesCap() async throws {
        let counter = AttemptCounter()
        let chain = InterceptorChain(
            interceptors: [RetryInterceptor(maxRetries: 0, baseDelay: .milliseconds(1))],
            transport: alwaysFailing(counter)
        )

        await #expect(throws: NetworkError.self) {
            _ = try await chain.execute(makeRequest(options: RequestOptions(maxRetries: 4)))
        }
        #expect(await counter.attempts == 5)
    }

    @Test("429 is retried and recovers within the cap")
    func rateLimitIsRetried() async throws {
        let counter = AttemptCounter()
        let transport: Next = { _ throws(NetworkError) in
            let attempt = await counter.next()
            guard attempt >= 3 else {
                throw NetworkError.unacceptableStatus(code: 429, data: Data(), headers: [:])
            }
            return NetworkResponse(statusCode: 200)
        }
        let chain = InterceptorChain(
            interceptors: [RetryInterceptor(maxRetries: 2, baseDelay: .milliseconds(1))],
            transport: transport
        )

        let response = try await chain.execute(makeRequest())
        #expect(response.statusCode == 200)
        #expect(await counter.attempts == 3)
    }

    @Test("A Retry-After hint replaces the exponential backoff")
    func retryAfterReplacesBackoff() async throws {
        let counter = AttemptCounter()
        let transport: Next = { _ throws(NetworkError) in
            let attempt = await counter.next()
            guard attempt >= 2 else {
                throw NetworkError.unacceptableStatus(code: 429, data: Data(), headers: ["Retry-After": "0"])
            }
            return NetworkResponse(statusCode: 200)
        }
        // A 10 s base backoff would blow this test's runtime; Retry-After: 0
        // must win, making the retry immediate.
        let chain = InterceptorChain(
            interceptors: [RetryInterceptor(maxRetries: 1, baseDelay: .seconds(10))],
            transport: transport
        )

        let clock = ContinuousClock()
        let start = clock.now
        let response = try await chain.execute(makeRequest())
        let elapsed = clock.now - start

        #expect(response.statusCode == 200)
        #expect(await counter.attempts == 2)
        #expect(elapsed < .seconds(2))
    }
}
