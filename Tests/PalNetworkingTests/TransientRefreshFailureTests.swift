import Foundation
import Testing
@testable import PalNetworking

/// Refresher errors that aren't wrapped in `TransientRefreshFailure`, retriable
/// ones included.
enum UnwrappedRefreshFailure: String, CaseIterable, Sendable {
    case timeout, offline, connectionLost, serverError503, rateLimited429, appError

    var error: any Error {
        switch self {
        case .timeout: NetworkError.transport(URLError(.timedOut))
        case .offline: NetworkError.transport(URLError(.notConnectedToInternet))
        case .connectionLost: NetworkError.transport(URLError(.networkConnectionLost))
        case .serverError503: NetworkError.unacceptableStatus(code: 503, data: Data(), headers: [:])
        case .rateLimited429: NetworkError.unacceptableStatus(code: 429, data: Data(), headers: ["Retry-After": "1"])
        case .appError: CocoaError(.coderReadCorrupt)
        }
    }
}

@Suite("TransientRefreshFailure keeps the session")
struct TransientRefreshFailureTests {

    @Test("A kept session fails the waiting call once, with the carried error, and keeps the tokens")
    func keptSessionFailsTheCallWithTheCarriedError() async throws {
        let store = InMemoryTokenStore(tokens: expiredPair)
        let refresher = FailingRefresher(throwing: TransientRefreshFailure(.transport(URLError(.timedOut))))
        let provider = TokenProvider(store: store, refresher: refresher)
        let backend = TokenCheckingBackend(rejecting: tokenRejection)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), backend])

        let error = await thrownError { try await client.send(Request<Data>(path: "/items")) }

        #expect(error?.urlError?.code == .timedOut)
        #expect(await store.tokens() == expiredPair)
        #expect(await refresher.attempts == 1)
        #expect(await backend.calls == 1)
        #expect(await events(of: provider).isEmpty)
    }

    @Test("An outer RetryInterceptor retries a kept session's retriable error, refresh included", arguments: [
        (URLError.Code.timedOut, 3),
        (.networkConnectionLost, 3),
        (.notConnectedToInternet, 1),
    ])
    func outerRetryRetriesARetriableCarriedError(code: URLError.Code, expectedAttempts: Int) async throws {
        let store = InMemoryTokenStore(tokens: expiredPair)
        let refresher = FailingRefresher(throwing: TransientRefreshFailure(.transport(URLError(code))))
        let provider = TokenProvider(store: store, refresher: refresher)
        let backend = TokenCheckingBackend(rejecting: tokenRejection)
        let client = try makeClient([
            RetryInterceptor(maxRetries: 2, baseDelay: .milliseconds(1)),
            AuthInterceptor(tokenProvider: provider),
            backend,
        ])

        let error = await thrownError { try await client.send(Request<Data>(path: "/items")) }

        #expect(error?.urlError?.code == code)
        #expect(await refresher.attempts == expectedAttempts)
        #expect(await backend.calls == expectedAttempts)
        #expect(await store.tokens() == expiredPair)
    }

    @Test("An error the refresher doesn't wrap still ends the session after one attempt")
    func unwrappedFailureEndsTheSessionAfterOneAttempt() async throws {
        let store = InMemoryTokenStore(tokens: expiredPair)
        let refresher = FailingRefresher(throwing: NetworkError.transport(URLError(.timedOut)))
        let provider = TokenProvider(store: store, refresher: refresher)
        let client = try makeClient([
            RetryInterceptor(maxRetries: 2, baseDelay: .milliseconds(1)),
            AuthInterceptor(tokenProvider: provider),
            TokenCheckingBackend(rejecting: tokenRejection),
        ])

        let error = await thrownError { try await client.send(Request<Data>(path: "/items")) }

        #expect(error?.statusCode == 401)
        #expect(await refresher.attempts == 1)
        #expect(await store.tokens() == nil)
        #expect(await events(of: provider) == [.loggedOut])
    }

    @Test("Every refresher error that isn't wrapped ends the session", arguments: UnwrappedRefreshFailure.allCases)
    func everyUnwrappedFailureEndsTheSession(_ failure: UnwrappedRefreshFailure) async throws {
        let store = InMemoryTokenStore(tokens: expiredPair)
        let provider = TokenProvider(store: store, refresher: FailingRefresher(throwing: failure.error))
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), TokenCheckingBackend(rejecting: tokenRejection)])

        let error = await thrownError { try await client.send(Request<Data>(path: "/items")) }

        #expect(error?.statusCode == 401)
        #expect(await store.tokens() == nil)
        #expect(await events(of: provider) == [.loggedOut])
    }

    /// The pause before the gate opens gives a second refresh, if one were started,
    /// the time to reach the refresher.
    @Test("Calls that overlap a failing refresh share it", arguments: 1...20)
    func overlappingCallsShareOneFailingRefresh(run: Int) async throws {
        let store = InMemoryTokenStore(tokens: expiredPair)
        let gate = Gate()
        let refresher = FailingRefresher(
            throwing: TransientRefreshFailure(.transport(URLError(.notConnectedToInternet))),
            holdingAt: gate
        )
        let provider = TokenProvider(store: store, refresher: refresher)
        let backend = TokenCheckingBackend(rejecting: tokenRejection)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), backend])

        let calls = (0..<3).map { index in
            Task { await thrownError { try await client.send(Request<Data>(path: "/items/\(index)")) } }
        }
        let allRejected = await waitUntil {
            let rejected = await backend.calls
            let attempts = await refresher.attempts
            return rejected == 3 && attempts == 1
        }
        #expect(allRejected)
        try await Task.sleep(for: .milliseconds(50))
        await gate.open()
        var errors: [NetworkError?] = []
        for call in calls {
            errors.append(await call.value)
        }

        #expect(errors.allSatisfy { $0?.urlError?.code == .notConnectedToInternet })
        #expect(await refresher.attempts == 1)
        #expect(await store.tokens() == expiredPair)
    }

    @Test("Without a quiet period, each later call tries the refresh again")
    func eachLaterCallTriesTheRefreshAgain() async throws {
        let store = InMemoryTokenStore(tokens: expiredPair)
        let refresher = FailingRefresher(throwing: TransientRefreshFailure(.transport(URLError(.notConnectedToInternet))))
        let provider = TokenProvider(store: store, refresher: refresher)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), TokenCheckingBackend(rejecting: tokenRejection)])

        for path in ["/a", "/b", "/c"] {
            _ = await thrownError { try await client.send(Request<Data>(path: path)) }
        }

        #expect(await refresher.attempts == 3)
        #expect(await store.tokens() == expiredPair)
    }

    @Test("An app's refresher keeps the session on a timeout, through a separate auth client")
    func appRefresherKeepsTheSessionOnATimeout() async throws {
        let store = InMemoryTokenStore(tokens: expiredPair)
        let endpoint = TokenEndpoint(failing: .transport(URLError(.timedOut)))
        let authClient = try makeClient([endpoint])
        let provider = TokenProvider(store: store, refresher: SessionKeepingRefresher(client: authClient))
        let apiClient = try makeClient([AuthInterceptor(tokenProvider: provider), TokenCheckingBackend(rejecting: tokenRejection)])

        let error = await thrownError { try await apiClient.send(Request<Data>(path: "/items")) }

        #expect(error?.urlError?.code == .timedOut)
        #expect(await endpoint.posts == 1)
        #expect(await store.tokens() == expiredPair)
        #expect(await events(of: provider).isEmpty)
    }

    @Test("An app's refresher still ends the session when the token endpoint answers 502")
    func appRefresherStillEndsTheSessionOnA502() async throws {
        let store = InMemoryTokenStore(tokens: expiredPair)
        let endpoint = TokenEndpoint(failing: .unacceptableStatus(code: 502, data: Data(), headers: [:]))
        let authClient = try makeClient([endpoint])
        let provider = TokenProvider(store: store, refresher: SessionKeepingRefresher(client: authClient))
        let apiClient = try makeClient([AuthInterceptor(tokenProvider: provider), TokenCheckingBackend(rejecting: tokenRejection)])

        let error = await thrownError { try await apiClient.send(Request<Data>(path: "/items")) }

        #expect(error?.statusCode == 401)
        #expect(await store.tokens() == nil)
        #expect(await events(of: provider) == [.loggedOut])
    }

    @Test("A direct refresh() throws refreshFailed while the session is kept")
    func directRefreshThrowsRefreshFailedWhileTheSessionIsKept() async throws {
        let store = InMemoryTokenStore(tokens: expiredPair)
        let provider = TokenProvider(
            store: store,
            refresher: FailingRefresher(throwing: TransientRefreshFailure(.transport(URLError(.timedOut))))
        )

        await #expect(throws: AuthError.refreshFailed) {
            try await provider.refresh()
        }
        #expect(await store.tokens() == expiredPair)
        #expect(await events(of: provider).isEmpty)
    }
}
