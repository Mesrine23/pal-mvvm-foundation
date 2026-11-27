import Foundation
import os
import Testing
@testable import PalNetworking

private actor AttemptCounter {

    private(set) var attempts = 0

    func next() -> Int {
        attempts += 1
        return attempts
    }
}

private struct ErrorCode: Decodable {
    let code: String
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

    private func alwaysFailing(with error: NetworkError, _ counter: AttemptCounter) -> Next {
        { _ throws(NetworkError) in
            _ = await counter.next()
            throw error
        }
    }

    private static let validation500 = NetworkError.unacceptableStatus(
        code: 500,
        data: Data(#"{"code":"VALIDATION"}"#.utf8),
        headers: [:]
    )

    private static func skipsValidationErrors(_ error: NetworkError) -> Bool {
        error.isRetriable && error.serverError(as: ErrorCode.self)?.code != "VALIDATION"
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

    @Test("By default a 500 is retried, even when its body says it's a validation error")
    func defaultRetriesAValidation500() async throws {
        let counter = AttemptCounter()
        let chain = InterceptorChain(
            interceptors: [RetryInterceptor(maxRetries: 2, baseDelay: .milliseconds(1))],
            transport: alwaysFailing(with: Self.validation500, counter)
        )

        await #expect(throws: NetworkError.self) {
            _ = try await chain.execute(makeRequest())
        }
        #expect(await counter.attempts == 3)
    }

    @Test("A shouldRetry predicate lets the app skip a validation 500")
    func predicateSkipsAValidation500() async throws {
        let counter = AttemptCounter()
        let chain = InterceptorChain(
            interceptors: [RetryInterceptor(maxRetries: 2, baseDelay: .milliseconds(1), shouldRetry: Self.skipsValidationErrors)],
            transport: alwaysFailing(with: Self.validation500, counter)
        )

        let request = try makeRequest()
        do {
            _ = try await chain.execute(request)
            Issue.record("Expected the validation 500")
        } catch {
            #expect(error.statusCode == 500)
        }
        #expect(await counter.attempts == 1)
    }

    @Test("A shouldRetry predicate still retries a real outage")
    func predicateStillRetriesAnOutage() async throws {
        let counter = AttemptCounter()
        let chain = InterceptorChain(
            interceptors: [RetryInterceptor(maxRetries: 2, baseDelay: .milliseconds(1), shouldRetry: Self.skipsValidationErrors)],
            transport: alwaysFailing(counter, status: 503)
        )

        await #expect(throws: NetworkError.self) {
            _ = try await chain.execute(makeRequest())
        }
        #expect(await counter.attempts == 3)
    }

    @Test("A cancelled failure is never retried, whatever the predicate says")
    func cancelledFailureIsNeverRetried() async throws {
        let retries = [
            RetryInterceptor(maxRetries: 2, baseDelay: .milliseconds(1)),
            RetryInterceptor(maxRetries: 2, baseDelay: .milliseconds(1)) { _ in true },
        ]
        for retry in retries {
            let counter = AttemptCounter()
            let chain = InterceptorChain(interceptors: [retry], transport: alwaysFailing(with: .cancelled, counter))

            let request = try makeRequest()
            do {
                _ = try await chain.execute(request)
                Issue.record("Expected .cancelled")
            } catch {
                guard case .cancelled = error else {
                    Issue.record("Expected .cancelled, got \(error)")
                    continue
                }
            }
            #expect(await counter.attempts == 1)
        }
    }

    @Test("The predicate is asked only while retries remain, and never about a cancelled call", arguments: [
        (NetworkError.unacceptableStatus(code: 503, data: Data(), headers: [:]), 0, 0),
        (NetworkError.unacceptableStatus(code: 503, data: Data(), headers: [:]), 2, 2),
        (NetworkError.cancelled, 2, 0),
    ])
    func predicateIsAskedOnlyWhileRetriesRemain(failure: NetworkError, maxRetries: Int, expectedQuestions: Int) async throws {
        let questions = OSAllocatedUnfairLock(initialState: 0)
        let retry = RetryInterceptor(maxRetries: maxRetries, baseDelay: .milliseconds(1)) { _ in
            questions.withLock { $0 += 1 }
            return true
        }
        let chain = InterceptorChain(interceptors: [retry], transport: alwaysFailing(with: failure, AttemptCounter()))

        await #expect(throws: NetworkError.self) {
            _ = try await chain.execute(makeRequest())
        }
        #expect(questions.withLock { $0 } == expectedQuestions)
    }

    @Test("A cancelled task isn't retried, even when the predicate says yes")
    func cancelledTaskIsNotRetried() async throws {
        let counter = AttemptCounter()
        let transport: Next = { _ throws(NetworkError) in
            _ = await counter.next()
            withUnsafeCurrentTask { $0?.cancel() }
            throw NetworkError.unacceptableStatus(code: 503, data: Data(), headers: [:])
        }
        let chain = InterceptorChain(
            interceptors: [RetryInterceptor(maxRetries: 2, baseDelay: .milliseconds(1)) { _ in true }],
            transport: transport
        )
        let request = try makeRequest()

        let failure = await Task { () -> NetworkError? in
            do {
                _ = try await chain.execute(request)
                return nil
            } catch {
                return error as? NetworkError
            }
        }.value

        guard case .cancelled? = failure else {
            Issue.record("Expected .cancelled, got \(String(describing: failure))")
            return
        }
        #expect(await counter.attempts == 1)
    }
}
