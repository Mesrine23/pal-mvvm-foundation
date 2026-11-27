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

// MARK: - A refresher as an app writes one: the PalNetworking guide's, so change both together

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
            options: RequestOptions(requiresAuth: false, timeout: .seconds(10), maxRetries: 0)
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
        } catch {
            if error.keepsSession {
                throw TransientRefreshFailure(error)
            }
            throw error
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
        } catch {
            if error.statusCode == 503 {
                throw TransientRefreshFailure(error, retryAfter: error.retryAfter)
            }
            if error.keepsSession {
                throw TransientRefreshFailure(error, retryAfter: .seconds(2))
            }
            throw error
        }
    }
}

// MARK: - Sessions, late rejections and logOut()

let stalePair = AuthTokens(accessToken: "access-0", refreshToken: "refresh-0")
let loginPair = AuthTokens(accessToken: "login-access", refreshToken: "login-refresh")

/// Any token but the stale pair's, such as the ones ``GatedRefresher`` issues.
func acceptsRefreshedTokens(_ authorization: String?) -> Bool {
    authorization != nil && authorization != "Bearer access-0"
}

/// An in-memory token store that can hold its next read, save or clear at a gate:
/// a read returns the value it found before waiting, and a held save or clear
/// takes effect only once the gate opens, so other store calls overtake it.
actor GatedTokenStore: TokenStore {
    private var current: AuthTokens?
    private var readGate: Gate?
    private var saveGate: Gate?
    private var clearGate: Gate?
    private(set) var saves: [AuthTokens] = []
    private(set) var clearCount = 0
    private(set) var isReadHeld = false
    private(set) var isSaveHeld = false
    private(set) var isClearHeld = false

    init(_ tokens: AuthTokens?) {
        current = tokens
    }

    func tokens() async -> AuthTokens? {
        let value = current
        if let gate = readGate {
            readGate = nil
            isReadHeld = true
            await gate.wait()
            isReadHeld = false
        }
        return value
    }

    func save(_ tokens: AuthTokens) async {
        if let gate = saveGate {
            saveGate = nil
            isSaveHeld = true
            await gate.wait()
            isSaveHeld = false
        }
        current = tokens
        saves.append(tokens)
    }

    func clear() async {
        if let gate = clearGate {
            clearGate = nil
            isClearHeld = true
            await gate.wait()
            isClearHeld = false
        }
        current = nil
        clearCount += 1
    }

    func holdNextRead(until gate: Gate) {
        readGate = gate
    }

    func holdNextSave(until gate: Gate) {
        saveGate = gate
    }

    func holdNextClear(until gate: Gate) {
        clearGate = gate
    }
}

/// The API's inner end: records each call, holds the first `holding` calls until
/// ``release()``, and fails a call with ``tokenRejection`` unless it accepts it.
actor HoldingBackend: Interceptor {
    struct Call: Sendable, Equatable {
        let path: String
        let authorization: String?
    }

    private(set) var calls: [Call] = []
    private(set) var rejections = 0
    private var holdsLeft: Int
    private var held: [CheckedContinuation<Void, Never>] = []
    private let accepts: @Sendable (_ path: String, _ authorization: String?) -> Bool

    init(holding: Int = 0, accepts: @escaping @Sendable (_ authorization: String?) -> Bool) {
        self.init(holding: holding) { _, authorization in accepts(authorization) }
    }

    init(holding: Int = 0, acceptsCall: @escaping @Sendable (_ path: String, _ authorization: String?) -> Bool) {
        holdsLeft = holding
        accepts = acceptsCall
    }

    var heldCount: Int {
        held.count
    }

    func intercept(_ request: TransportRequest, next: Next) async throws(NetworkError) -> NetworkResponse {
        let authorization = request.urlRequest.value(forHTTPHeaderField: "Authorization")
        let path = request.urlRequest.url?.path ?? ""
        calls.append(Call(path: path, authorization: authorization))
        if holdsLeft > 0 {
            holdsLeft -= 1
            await withCheckedContinuation { held.append($0) }
        }
        guard accepts(path, authorization) else {
            rejections += 1
            throw tokenRejection
        }
        return NetworkResponse(statusCode: 200, data: Data("ok".utf8))
    }

    func release() {
        let releasing = held
        held.removeAll()
        releasing.forEach { $0.resume() }
    }
}

/// Issues "access-N" and "refresh-N" on its Nth call, once that call's gate opens
/// (`gates[N]`, else `gate`), unless `failure` returns an error for the call.
actor GatedRefresher: TokenRefreshService {
    private(set) var refreshTokensSent: [String] = []
    private let gate: Gate?
    private let gates: [Int: Gate]
    private let failure: @Sendable (_ call: Int) -> (any Error)?

    init(gate: Gate? = nil, gates: [Int: Gate] = [:], failure: @escaping @Sendable (_ call: Int) -> (any Error)? = { _ in nil }) {
        self.gate = gate
        self.gates = gates
        self.failure = failure
    }

    var attempts: Int {
        refreshTokensSent.count
    }

    func refresh(using refreshToken: String) async throws -> AuthTokens {
        refreshTokensSent.append(refreshToken)
        let call = refreshTokensSent.count
        await (gates[call] ?? gate)?.wait()
        if let error = failure(call) {
            throw error
        }
        return AuthTokens(accessToken: "access-\(call)", refreshToken: "refresh-\(call)")
    }
}

/// How a started call or refresh ended. A test waits for it with `waitUntil`
/// instead of awaiting work that a broken guard may have left blocked at a gate.
actor Completion<Failure: Error> {
    private(set) var isDone = false
    private(set) var failure: Failure?

    func finish(with failure: Failure?) {
        self.failure = failure
        isDone = true
    }
}

func startCall(_ call: @escaping @Sendable () async throws -> Data) -> Completion<NetworkError> {
    let completion = Completion<NetworkError>()
    Task { await completion.finish(with: await thrownError(call)) }
    return completion
}

func startRefresh(_ provider: TokenProvider) -> Completion<AuthError> {
    let completion = Completion<AuthError>()
    Task {
        do {
            _ = try await provider.refresh()
            await completion.finish(with: nil)
        } catch {
            await completion.finish(with: error as? AuthError)
        }
    }
    return completion
}
