import Foundation
import Testing
@testable import PalNetworking

private let unreachableHost = NetworkError.transport(URLError(.cannotConnectToHost))

/// Fails the expired pair's refresh token temporarily, asking for `retryAfter`;
/// any other refresh token gets the valid pair.
private func failingTheExpiredPair(with failure: NetworkError, retryAfter: Duration?) -> ScriptedRefresher {
    ScriptedRefresher { _, refreshToken in
        guard refreshToken != expiredPair.refreshToken else {
            throw TransientRefreshFailure(failure, retryAfter: retryAfter)
        }
        return validPair
    }
}

/// The connection drops during the first refresh and is back for the second.
private func flakyRefresher(retryAfter: Duration?) -> ScriptedRefresher {
    ScriptedRefresher { attempt, _ in
        guard attempt > 1 else {
            throw TransientRefreshFailure(.transport(URLError(.timedOut)), retryAfter: retryAfter)
        }
        return validPair
    }
}

/// A token server that never answers: each attempt waits out its timeout, then fails.
private func slowFailingRefresher(wait: Duration, retryAfter: Duration?) -> ScriptedRefresher {
    ScriptedRefresher { _, _ in
        try await Task.sleep(for: wait)
        throw TransientRefreshFailure(.transport(URLError(.timedOut)), retryAfter: retryAfter)
    }
}

private func timeToFail(_ client: HTTPClient) async -> Duration {
    let clock = ContinuousClock()
    let start = clock.now
    _ = await thrownError { try await client.send(Request<Data>(path: "/items")) }
    return clock.now - start
}

@Suite("TransientRefreshFailure's quiet period")
struct QuietPeriodTests {

    @Test("Later rejections get the carried error without calling the refresher")
    func laterRejectionsGetTheCarriedError() async throws {
        let store = InMemoryTokenStore(tokens: expiredPair)
        let refresher = failingTheExpiredPair(with: unreachableHost, retryAfter: .seconds(30))
        let provider = TokenProvider(store: store, refresher: refresher)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), TokenCheckingBackend(rejecting: tokenRejection)])

        var codes: [URLError.Code?] = []
        for path in ["/a", "/b", "/c"] {
            codes.append(await thrownError { try await client.send(Request<Data>(path: path)) }?.urlError?.code)
        }

        #expect(codes == [.cannotConnectToHost, .cannotConnectToHost, .cannotConnectToHost])
        #expect(await refresher.attempts == 1)
        #expect(await store.tokens() == expiredPair)
        #expect(await events(of: provider).isEmpty)
    }

    /// The sleep is the input here: it outlasts the 60 ms period.
    @Test("The next rejection after the period tries again")
    func nextRejectionAfterThePeriodTriesAgain() async throws {
        let refresher = failingTheExpiredPair(with: unreachableHost, retryAfter: .milliseconds(60))
        let provider = TokenProvider(store: InMemoryTokenStore(tokens: expiredPair), refresher: refresher)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), TokenCheckingBackend(rejecting: tokenRejection)])

        _ = await thrownError { try await client.send(Request<Data>(path: "/a")) }
        try await Task.sleep(for: .milliseconds(150))
        _ = await thrownError { try await client.send(Request<Data>(path: "/b")) }

        #expect(await refresher.attempts == 2)
    }

    @Test("An outer retry costs one refresher call inside a quiet period")
    func outerRetryCostsOneRefresherCall() async throws {
        let refresher = failingTheExpiredPair(with: .transport(URLError(.timedOut)), retryAfter: .seconds(30))
        let provider = TokenProvider(store: InMemoryTokenStore(tokens: expiredPair), refresher: refresher)
        let backend = TokenCheckingBackend(rejecting: tokenRejection)
        let client = try makeClient([
            RetryInterceptor(maxRetries: 2, baseDelay: .milliseconds(1)),
            AuthInterceptor(tokenProvider: provider),
            backend,
        ])

        let error = await thrownError { try await client.send(Request<Data>(path: "/items")) }

        #expect(error?.urlError?.code == .timedOut)
        #expect(await backend.calls == 3)
        #expect(await refresher.attempts == 1)
    }

    @Test("A new login isn't held by the old session's quiet period")
    func newLoginIsNotHeld() async throws {
        let store = InMemoryTokenStore(tokens: expiredPair)
        let refresher = failingTheExpiredPair(with: unreachableHost, retryAfter: .seconds(30))
        let provider = TokenProvider(store: store, refresher: refresher)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), TokenCheckingBackend(rejecting: tokenRejection)])

        _ = await thrownError { try await client.send(Request<Data>(path: "/a")) }
        await store.save(AuthTokens(accessToken: "new-but-expired", refreshToken: "r9"))
        let error = await thrownError { try await client.send(Request<Data>(path: "/b")) }

        #expect(error == nil)
        #expect(await refresher.attempts == 2)
    }

    @Test("The server's Retry-After can set the period")
    func serversRetryAfterSetsThePeriod() async throws {
        let unavailable = NetworkError.unacceptableStatus(code: 503, data: Data(), headers: ["Retry-After": "120"])
        let endpoint = TokenEndpoint(failing: unavailable)
        let authClient = try makeClient([endpoint])
        let provider = TokenProvider(store: InMemoryTokenStore(tokens: expiredPair), refresher: QuietPeriodRefresher(client: authClient))
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), TokenCheckingBackend(rejecting: tokenRejection)])

        let first = await thrownError { try await client.send(Request<Data>(path: "/a")) }
        let second = await thrownError { try await client.send(Request<Data>(path: "/b")) }

        #expect(first?.statusCode == 503)
        #expect(second?.statusCode == 503)
        #expect(await endpoint.posts == 1)
    }

    @Test("Without a quiet period, the user's retry works once the connection is back")
    func withoutAQuietPeriodTheRetryWorks() async throws {
        let refresher = flakyRefresher(retryAfter: nil)
        let provider = TokenProvider(store: InMemoryTokenStore(tokens: expiredPair), refresher: refresher)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), TokenCheckingBackend(rejecting: tokenRejection)])

        let first = await thrownError { try await client.send(Request<Data>(path: "/items")) }
        let retry = await thrownError { try await client.send(Request<Data>(path: "/items")) }

        #expect(first?.urlError?.code == .timedOut)
        #expect(retry == nil)
        #expect(await refresher.attempts == 2)
        #expect(await events(of: provider) == [.refreshed])
    }

    @Test("With a quiet period, the user's retry fails until it ends")
    func withAQuietPeriodTheRetryFails() async throws {
        let refresher = flakyRefresher(retryAfter: .seconds(30))
        let provider = TokenProvider(store: InMemoryTokenStore(tokens: expiredPair), refresher: refresher)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), TokenCheckingBackend(rejecting: tokenRejection)])

        _ = await thrownError { try await client.send(Request<Data>(path: "/items")) }
        let retry = await thrownError { try await client.send(Request<Data>(path: "/items")) }

        #expect(retry?.urlError?.code == .timedOut)
        #expect(await refresher.attempts == 1)
    }

    @Test("Without a quiet period, an outer retry waits out every refresh attempt")
    func withoutAQuietPeriodAnOuterRetryWaitsOutEveryAttempt() async throws {
        let refresher = slowFailingRefresher(wait: .milliseconds(100), retryAfter: nil)
        let provider = TokenProvider(store: InMemoryTokenStore(tokens: expiredPair), refresher: refresher)
        let client = try makeClient([
            RetryInterceptor(maxRetries: 2, baseDelay: .milliseconds(1)),
            AuthInterceptor(tokenProvider: provider),
            TokenCheckingBackend(rejecting: tokenRejection),
        ])

        let elapsed = await timeToFail(client)

        #expect(await refresher.attempts == 3)
        #expect(elapsed >= .milliseconds(300))
    }

    @Test("A slow failing refresh still starts the period, so the outer retries skip the refresher")
    func slowFailingRefreshStartsThePeriod() async throws {
        let refresher = slowFailingRefresher(wait: .milliseconds(100), retryAfter: .seconds(5))
        let provider = TokenProvider(store: InMemoryTokenStore(tokens: expiredPair), refresher: refresher)
        let backend = TokenCheckingBackend(rejecting: tokenRejection)
        let client = try makeClient([
            RetryInterceptor(maxRetries: 2, baseDelay: .milliseconds(1)),
            AuthInterceptor(tokenProvider: provider),
            backend,
        ])

        let elapsed = await timeToFail(client)

        #expect(await refresher.attempts == 1)
        #expect(await backend.calls == 3)
        #expect(elapsed >= .milliseconds(100))
    }

    @Test("Two seconds cover an outer RetryInterceptor's default backoff")
    func twoSecondsCoverTheDefaultBackoff() async throws {
        let endpoint = TokenEndpoint(failing: .transport(URLError(.timedOut)))
        let authClient = try makeClient([endpoint])
        let provider = TokenProvider(store: InMemoryTokenStore(tokens: expiredPair), refresher: QuietPeriodRefresher(client: authClient))
        let backend = TokenCheckingBackend(rejecting: tokenRejection)
        let client = try makeClient([RetryInterceptor(), AuthInterceptor(tokenProvider: provider), backend])

        let elapsed = await timeToFail(client)

        #expect(await backend.calls == 3)
        #expect(await endpoint.posts == 1)
        #expect(elapsed >= .milliseconds(900))
    }

    @Test("A direct refresh() during the period throws refreshFailed without calling the refresher")
    func directRefreshDuringThePeriodSkipsTheRefresher() async throws {
        let store = InMemoryTokenStore(tokens: expiredPair)
        let refresher = failingTheExpiredPair(with: unreachableHost, retryAfter: .seconds(30))
        let provider = TokenProvider(store: store, refresher: refresher)

        await #expect(throws: AuthError.refreshFailed) { try await provider.refresh() }
        await #expect(throws: AuthError.refreshFailed) { try await provider.refresh() }

        #expect(await refresher.attempts == 1)
        #expect(await store.tokens() == expiredPair)
        #expect(await events(of: provider).isEmpty)
    }

    @Test("A zero or negative retryAfter holds nothing", arguments: [Duration.zero, .milliseconds(-5)])
    func zeroOrNegativeRetryAfterHoldsNothing(retryAfter: Duration) async throws {
        let refresher = failingTheExpiredPair(with: unreachableHost, retryAfter: retryAfter)
        let provider = TokenProvider(store: InMemoryTokenStore(tokens: expiredPair), refresher: refresher)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), TokenCheckingBackend(rejecting: tokenRejection)])

        _ = await thrownError { try await client.send(Request<Data>(path: "/a")) }
        _ = await thrownError { try await client.send(Request<Data>(path: "/b")) }

        #expect(await refresher.attempts == 2)
    }
}
