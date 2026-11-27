import Foundation
import Testing
@testable import PalNetworking

/// The body this backend sends with a 401: its message tells a rejected token
/// from a rejected API key.
private struct ErrorBody: Decodable {
    let message: String
}

private func rejectsTheTokenByBody(_ error: NetworkError) -> Bool {
    guard error.statusCode == 401 else { return false }
    let message = error.serverError(as: ErrorBody.self)?.message ?? ""
    return !message.localizedCaseInsensitiveContains("API key")
}

private func rejectsTheTokenByChallenge(_ error: NetworkError) -> Bool {
    guard error.statusCode == 401 else { return false }
    let challenge = error.responseHeaders?
        .first { $0.key.caseInsensitiveCompare("WWW-Authenticate") == .orderedSame }?
        .value
    return challenge?.contains("invalid_token") ?? false
}

/// This backend reports every error as HTTP 200 with `{"error": "…"}`.
private struct ErrorEnvelope: Decodable {
    let error: String?
}

/// Turns the backend's 200-with-an-error answers into errors, keeping the real
/// status and body.
private struct ErrorEnvelopeInterceptor: Interceptor {
    func intercept(_ request: TransportRequest, next: Next) async throws(NetworkError) -> NetworkResponse {
        let response = try await next(request)
        let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: response.data)
        guard envelope?.error != nil else {
            return response
        }
        throw .unacceptableStatus(code: response.statusCode, data: response.data, headers: response.headers)
    }
}

/// Answers HTTP 200 to everything; the body depends on whether the call carried
/// the valid token.
private actor EnvelopeBackend: Interceptor {
    private(set) var calls = 0
    private let validAnswer: String
    private let staleAnswer: String

    init(validAnswer: String = #"{"items":[]}"#, staleAnswer: String) {
        self.validAnswer = validAnswer
        self.staleAnswer = staleAnswer
    }

    func intercept(_ request: TransportRequest, next: Next) async throws(NetworkError) -> NetworkResponse {
        calls += 1
        let isValid = request.urlRequest.value(forHTTPHeaderField: "Authorization") == "Bearer valid"
        return NetworkResponse(statusCode: 200, data: Data((isValid ? validAnswer : staleAnswer).utf8))
    }
}

private struct Fault: Decodable {
    let code: String
}

@Suite("AuthInterceptor token rejections")
struct AuthInterceptorTests {

    @Test("By default any 401 is a token rejection, so a rejected API key ends a valid session")
    func defaultEndsAValidSessionOnARejectedAPIKey() async throws {
        let gateway = RejectingTransport { _ in apiKeyRejection }
        let store = InMemoryTokenStore(tokens: validPair)
        let authClient = try makeClient([gateway])
        let provider = TokenProvider(store: store, refresher: SessionKeepingRefresher(client: authClient))
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), gateway])

        let error = await thrownError { try await client.send(Request<Data>(path: "/items")) }

        #expect(error?.statusCode == 401)
        #expect(await store.tokens() == nil)
        #expect(await gateway.calls == ["GET /items", "POST /auth/refresh"])
        #expect(await events(of: provider) == [.loggedOut])
    }

    @Test("By default no status but 401 starts a refresh", arguments: [400, 403, 404, 500])
    func defaultRefreshesOnlyOn401(status: Int) async throws {
        let refresher = ValidPairRefresher()
        let provider = TokenProvider(store: InMemoryTokenStore(tokens: expiredPair), refresher: refresher)
        let rejection = NetworkError.unacceptableStatus(code: status, data: Data(), headers: [:])
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), TokenCheckingBackend(rejecting: rejection)])

        let error = await thrownError { try await client.send(Request<Data>(path: "/items")) }

        #expect(error?.statusCode == status)
        #expect(await refresher.attempts == 0)
    }

    @Test("By default every rejected API key costs a refresh when the token endpoint works")
    func defaultRefreshesForEveryRejectedAPIKey() async throws {
        let refresher = ValidPairRefresher()
        let provider = TokenProvider(store: InMemoryTokenStore(tokens: validPair), refresher: refresher)
        let client = try makeClient([AuthInterceptor(tokenProvider: provider), RejectingTransport { _ in apiKeyRejection }])

        for _ in 1...3 {
            _ = await thrownError { try await client.send(Request<Data>(path: "/items")) }
        }

        #expect(await refresher.attempts == 3)
        #expect(await events(of: provider) == [.refreshed, .refreshed, .refreshed])
    }

    @Test("A body predicate keeps a rejected API key away from the refresh")
    func bodyPredicateKeepsARejectedAPIKeyAwayFromTheRefresh() async throws {
        let store = InMemoryTokenStore(tokens: validPair)
        let refresher = ValidPairRefresher()
        let provider = TokenProvider(store: store, refresher: refresher)
        let client = try makeClient([
            AuthInterceptor(tokenProvider: provider, isTokenRejection: rejectsTheTokenByBody),
            RejectingTransport { _ in apiKeyRejection },
        ])

        let error = await thrownError { try await client.send(Request<Data>(path: "/items")) }

        #expect(error?.statusCode == 401)
        #expect(await refresher.attempts == 0)
        #expect(await store.tokens() == validPair)
        #expect(await events(of: provider).isEmpty)
    }

    @Test("A body predicate still refreshes a rejected token")
    func bodyPredicateStillRefreshesARejectedToken() async throws {
        let refresher = ValidPairRefresher()
        let provider = TokenProvider(store: InMemoryTokenStore(tokens: expiredPair), refresher: refresher)
        let client = try makeClient([
            AuthInterceptor(tokenProvider: provider, isTokenRejection: rejectsTheTokenByBody),
            TokenCheckingBackend(rejecting: tokenRejection),
        ])

        let error = await thrownError { try await client.send(Request<Data>(path: "/items")) }

        #expect(error == nil)
        #expect(await refresher.attempts == 1)
        #expect(await events(of: provider) == [.refreshed])
    }

    @Test("A header predicate refreshes only an invalid-token challenge", arguments: [
        (#"Bearer error="invalid_token""#, 1),
        (#"Bearer realm="api""#, 0),
    ])
    func headerPredicateRefreshesOnlyAnInvalidTokenChallenge(challenge: String, expectedRefreshes: Int) async throws {
        let refresher = ValidPairRefresher()
        let provider = TokenProvider(store: InMemoryTokenStore(tokens: expiredPair), refresher: refresher)
        let rejection = NetworkError.unacceptableStatus(code: 401, data: Data(), headers: ["www-authenticate": challenge])
        let client = try makeClient([
            AuthInterceptor(tokenProvider: provider, isTokenRejection: rejectsTheTokenByChallenge),
            TokenCheckingBackend(rejecting: rejection),
        ])

        _ = await thrownError { try await client.send(Request<Data>(path: "/items")) }

        #expect(await refresher.attempts == expectedRefreshes)
    }

    @Test("The trailing-closure form picks the predicate init")
    func trailingClosurePicksThePredicateInit() async throws {
        let refresher = ValidPairRefresher()
        let tokenProvider = TokenProvider(store: InMemoryTokenStore(tokens: validPair), refresher: refresher)
        let authInterceptor = AuthInterceptor(tokenProvider: tokenProvider) { error in
            error.statusCode == 401 && error.serverError(as: ErrorBody.self)?.message == "Unauthorized"
        }
        let client = try makeClient([authInterceptor, RejectingTransport { _ in apiKeyRejection }])

        let error = await thrownError { try await client.send(Request<Data>(path: "/items")) }

        #expect(error?.statusCode == 401)
        #expect(await refresher.attempts == 0)
    }

    @Test("A token error inside a 200 is refreshed like a 401")
    func tokenErrorInsideA200IsRefreshed() async throws {
        let refresher = ValidPairRefresher()
        let provider = TokenProvider(store: InMemoryTokenStore(tokens: expiredPair), refresher: refresher)
        let backend = EnvelopeBackend(staleAnswer: #"{"error":"token_expired"}"#)
        let client = try makeClient([
            AuthInterceptor(tokenProvider: provider) { error in
                error.serverError(as: ErrorEnvelope.self)?.error == "token_expired"
            },
            ErrorEnvelopeInterceptor(),
            backend,
        ])

        let error = await thrownError { try await client.send(Request<Data>(path: "/items")) }

        #expect(error == nil)
        #expect(await refresher.attempts == 1)
        #expect(await backend.calls == 2)
        #expect(await events(of: provider) == [.refreshed])
    }

    @Test("Any other error inside a 200 reaches the call without a refresh")
    func otherErrorInsideA200ReachesTheCall() async throws {
        let refresher = ValidPairRefresher()
        let provider = TokenProvider(store: InMemoryTokenStore(tokens: validPair), refresher: refresher)
        let backend = EnvelopeBackend(validAnswer: #"{"error":"not_found"}"#, staleAnswer: #"{"error":"token_expired"}"#)
        let client = try makeClient([
            AuthInterceptor(tokenProvider: provider) { error in
                error.serverError(as: ErrorEnvelope.self)?.error == "token_expired"
            },
            ErrorEnvelopeInterceptor(),
            backend,
        ])

        let error = await thrownError { try await client.send(Request<Data>(path: "/items/7")) }

        #expect(error?.statusCode == 200)
        #expect(error?.serverError(as: ErrorEnvelope.self)?.error == "not_found")
        #expect(await refresher.attempts == 0)
    }

    @Test("A backend that answers 403 for an expired token can opt in", arguments: [("TOKEN_EXPIRED", 1), ("FORBIDDEN", 0)])
    func backendThatAnswers403CanOptIn(code: String, expectedRefreshes: Int) async throws {
        let refresher = ValidPairRefresher()
        let provider = TokenProvider(store: InMemoryTokenStore(tokens: expiredPair), refresher: refresher)
        let rejection = NetworkError.unacceptableStatus(code: 403, data: Data(#"{"code":"\#(code)"}"#.utf8), headers: [:])
        let client = try makeClient([
            AuthInterceptor(tokenProvider: provider) { error in
                error.statusCode == 403 && error.serverError(as: Fault.self)?.code == "TOKEN_EXPIRED"
            },
            TokenCheckingBackend(rejecting: rejection),
        ])

        let error = await thrownError { try await client.send(Request<Data>(path: "/items")) }

        #expect(await refresher.attempts == expectedRefreshes)
        #expect((error == nil) == (expectedRefreshes == 1))
    }

    @Test("A failed refresh fails the call with its own 401; a rejected retry, with the retry's")
    func unfixableRejectionsSurfaceAsTheirOwn401() async throws {
        let numbered: @Sendable (Int) -> NetworkError = {
            .unacceptableStatus(code: 401, data: Data("401-#\($0)".utf8), headers: [:])
        }
        let failingProvider = TokenProvider(
            store: InMemoryTokenStore(tokens: expiredPair),
            refresher: FailingRefresher(throwing: CocoaError(.coderReadCorrupt))
        )
        let refreshFailed = try makeClient([AuthInterceptor(tokenProvider: failingProvider), RejectingTransport(numbered)])
        let workingProvider = TokenProvider(store: InMemoryTokenStore(tokens: expiredPair), refresher: ValidPairRefresher())
        let retryRejected = try makeClient([AuthInterceptor(tokenProvider: workingProvider), RejectingTransport(numbered)])

        let afterFailedRefresh = await thrownError { try await refreshFailed.send(Request<Data>(path: "/items")) }
        let afterRejectedRetry = await thrownError { try await retryRejected.send(Request<Data>(path: "/items")) }

        guard case .unacceptableStatus(401, let firstBody, _)? = afterFailedRefresh,
              case .unacceptableStatus(401, let secondBody, _)? = afterRejectedRetry else {
            Issue.record("Expected two 401s, got \(String(describing: afterFailedRefresh)) and \(String(describing: afterRejectedRetry))")
            return
        }
        #expect(String(decoding: firstBody, as: UTF8.self) == "401-#1")
        #expect(String(decoding: secondBody, as: UTF8.self) == "401-#2")
        #expect(await events(of: failingProvider) == [.loggedOut])
        #expect(await events(of: workingProvider) == [.refreshed])
    }

    @Test("A request that doesn't require auth starts no refresh, whatever the predicate says")
    func unauthenticatedRequestStartsNoRefresh() async throws {
        let refresher = ValidPairRefresher()
        let provider = TokenProvider(store: InMemoryTokenStore(tokens: expiredPair), refresher: refresher)
        let client = try makeClient([
            AuthInterceptor(tokenProvider: provider) { _ in true },
            RejectingTransport { _ in tokenRejection },
        ])

        let error = await thrownError {
            try await client.send(Request<Data>(method: .post, path: "/auth/refresh", options: RequestOptions(requiresAuth: false)))
        }

        #expect(error?.statusCode == 401)
        #expect(await refresher.attempts == 0)
    }
}
