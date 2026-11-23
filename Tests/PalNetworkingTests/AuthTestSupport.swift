import Foundation
import Testing
@testable import PalNetworking

let expiredPair = AuthTokens(accessToken: "expired", refreshToken: "r1")
let validPair = AuthTokens(accessToken: "valid", refreshToken: "r2")

let tokenRejection = NetworkError.unacceptableStatus(
    code: 401,
    data: Data(#"{"statusCode":401,"message":"Unauthorized"}"#.utf8),
    headers: [:]
)

let apiKeyRejection = NetworkError.unacceptableStatus(
    code: 401,
    data: Data(#"{"statusCode":401,"message":"Access denied: invalid API key."}"#.utf8),
    headers: [:]
)

func makeClient(_ interceptors: [any Interceptor]) throws -> HTTPClient {
    HTTPClient(baseURL: try #require(URL(string: "https://api.example.test")), interceptors: interceptors)
}

/// The `NetworkError` a call throws, or `nil` when it succeeds.
func thrownError(_ call: @Sendable () async throws -> Data) async -> NetworkError? {
    do {
        _ = try await call()
        return nil
    } catch {
        return error as? NetworkError
    }
}

/// Polls `condition` every 5 ms until it holds, for up to 2 seconds.
func waitUntil(_ condition: @Sendable () async -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + .seconds(2)
    while ContinuousClock.now < deadline {
        if await condition() {
            return true
        }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return await condition()
}

/// The events `provider` emitted, plus any that arrive within `window`.
///
/// Reading after a fixed wait is safe here: `TokenProvider` emits before the call
/// that caused the event returns, and the stream buffers, so every expected event
/// is already there. The window only gives an unexpected, late one the chance to
/// show. It iterates the single-consumer stream, so call it once per provider, last.
func events(of provider: TokenProvider, within window: Duration = .milliseconds(100)) async -> [AuthEvent] {
    let reader = Task {
        var seen: [AuthEvent] = []
        for await event in provider.events {
            seen.append(event)
        }
        return seen
    }
    try? await Task.sleep(for: window)
    reader.cancel()
    return await reader.value
}

/// A one-shot latch: `wait()` suspends until `open()` is called, or returns at once
/// if it already was.
actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}

/// The API's inner end: accepts only `Bearer valid`, fails every other call with
/// `rejection`, and counts the calls.
actor TokenCheckingBackend: Interceptor {
    private(set) var calls = 0
    private let rejection: NetworkError

    init(rejecting rejection: NetworkError) {
        self.rejection = rejection
    }

    func intercept(_ request: TransportRequest, next: Next) async throws(NetworkError) -> NetworkResponse {
        calls += 1
        guard request.urlRequest.value(forHTTPHeaderField: "Authorization") == "Bearer valid" else {
            throw rejection
        }
        return NetworkResponse(statusCode: 200, data: Data("ok".utf8))
    }
}

/// Fails every request, as a gateway in front of every endpoint would, and records
/// each call as `METHOD /path`.
actor RejectingTransport: Interceptor {
    private(set) var calls: [String] = []
    private let rejection: @Sendable (_ call: Int) -> NetworkError

    init(_ rejection: @escaping @Sendable (_ call: Int) -> NetworkError) {
        self.rejection = rejection
    }

    func intercept(_ request: TransportRequest, next: Next) async throws(NetworkError) -> NetworkResponse {
        calls.append("\(request.urlRequest.httpMethod ?? "") \(request.urlRequest.url?.path ?? "")")
        throw rejection(calls.count)
    }
}

/// The token endpoint's inner end: fails every refresh POST with `failure`, and
/// counts them.
actor TokenEndpoint: Interceptor {
    private(set) var posts = 0
    private let failure: NetworkError

    init(failing failure: NetworkError) {
        self.failure = failure
    }

    func intercept(_ request: TransportRequest, next: Next) async throws(NetworkError) -> NetworkResponse {
        posts += 1
        throw failure
    }
}

/// Fails every refresh with `error`, once `gate` (if any) opens, and counts its calls.
actor FailingRefresher: TokenRefreshService {
    private(set) var attempts = 0
    private let error: any Error
    private let gate: Gate?

    init(throwing error: any Error, holdingAt gate: Gate? = nil) {
        self.error = error
        self.gate = gate
    }

    func refresh(using refreshToken: String) async throws -> AuthTokens {
        attempts += 1
        await gate?.wait()
        throw error
    }
}

/// Answers every refresh with the valid pair, and counts its calls.
actor ValidPairRefresher: TokenRefreshService {
    private(set) var attempts = 0

    func refresh(using refreshToken: String) async throws -> AuthTokens {
        attempts += 1
        return validPair
    }
}

/// Answers each refresh from `script`, given the call's number (from 1) and the
/// refresh token it was sent, and counts its calls.
actor ScriptedRefresher: TokenRefreshService {
    private(set) var attempts = 0
    private let script: @Sendable (_ attempt: Int, _ refreshToken: String) async throws -> AuthTokens

    init(_ script: @escaping @Sendable (_ attempt: Int, _ refreshToken: String) async throws -> AuthTokens) {
        self.script = script
    }

    func refresh(using refreshToken: String) async throws -> AuthTokens {
        attempts += 1
        return try await script(attempts, refreshToken)
    }
}

// MARK: - A refresher as an app writes one

struct TokenPairDTO: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
}

extension Request where Response == TokenPairDTO {
    static func refreshTokens(_ refreshToken: String) -> Self {
        Request(
            method: .post,
            path: "/auth/refresh",
            body: .json(["refreshToken": refreshToken]),
            options: RequestOptions(requiresAuth: false, maxRetries: 0)
        )
    }
}

extension NetworkError {
    var keepsSession: Bool {
        switch urlError?.code {
        case .timedOut?, .notConnectedToInternet?, .networkConnectionLost?: true
        default: false
        }
    }
}

/// Keeps the session on a timeout or a lost connection; any other failure ends it.
struct SessionKeepingRefresher: TokenRefreshService {
    let client: any NetworkClient

    func refresh(using refreshToken: String) async throws -> AuthTokens {
        do {
            let pair = try await client.send(.refreshTokens(refreshToken))
            return AuthTokens(accessToken: pair.accessToken, refreshToken: pair.refreshToken)
        } catch where error.keepsSession {
            throw TransientRefreshFailure(error)
        }
    }
}

/// Like ``SessionKeepingRefresher``, and asks for a quiet period: the server's
/// `Retry-After` for a 503, two seconds for a timeout or a lost connection.
struct QuietPeriodRefresher: TokenRefreshService {
    let client: any NetworkClient

    func refresh(using refreshToken: String) async throws -> AuthTokens {
        do {
            let pair = try await client.send(.refreshTokens(refreshToken))
            return AuthTokens(accessToken: pair.accessToken, refreshToken: pair.refreshToken)
        } catch where error.statusCode == 503 {
            throw TransientRefreshFailure(error, retryAfter: error.retryAfter)
        } catch where error.keepsSession {
            throw TransientRefreshFailure(error, retryAfter: .seconds(2))
        }
    }
}
