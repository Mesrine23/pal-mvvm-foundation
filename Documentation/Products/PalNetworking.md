# PalNetworking

> A typed, `async`/`await` networking stack over `URLSession`: generic requests, an interceptor pipeline, typed errors, and single-flight auth refresh. Zero third-party transport. Dependencies: PalCore.

`import PalNetworking`

## What it gives you

- **`Request<Response>`** — a generic value type; endpoints are one-line static factories (query via `[URLQueryItem]` or ordered dictionary-literal syntax).
- **`NetworkClient` / `HTTPClient`** — `send(_:)` with **typed throws** (`NetworkError`); `sendWithResponse(_:)` when the call site needs the status code or response headers too.
- **Per-request options** — `timeout`, `maxRetries` (0 = never retry), `redirectPolicy` (`.follow`/`.deny`), `requiresAuth`, free-form `flags`.
- **Interceptor onion** — composable middleware over `TransportRequest`; ships `Logging`, `Retry`, `Auth`.
- **`TokenProvider`** — an actor doing single-flight token refresh: rejections that overlap a refresh share it. Which failures are token rejections, and which refresh failures keep the session, is your app's call.
- **Uploads** — multipart and file upload; raw `Data`/`String` responses bypass JSON decoding.

## Key types

| Symbol | Purpose |
|---|---|
| `Request<Response: Decodable & Sendable>` | method, path, query, headers, body, options. |
| `RequestOptions` | `requiresAuth`, `flags`, `timeout`, `maxRetries`, `redirectPolicy`. |
| `RedirectPolicy` | `.follow` (default) or `.deny` — a denied 3xx surfaces as `unacceptableStatus` with `Location` readable. |
| `HTTPBody` | `.json`, `.data(_:contentType:)`, `.multipart`, `.file(_:contentType:)`; `MultipartPart.text(…)`/`.file(…)` factories. |
| `NetworkClient` | `send(_:)` → decoded value; `sendWithResponse(_:)` → value + `NetworkResponse` (status, headers). |
| `HTTPClient` | Concrete client (immutable, `Sendable`); injectable session + decoder/encoder. |
| `NetworkError` | `invalidRequest`, `transport(URLError)`, `unacceptableStatus(code:data:headers:)`, `decoding`, `cancelled`; accessors `statusCode`, `urlError`, `responseHeaders`, `retryAfter`. |
| `Interceptor` / `Next` | `intercept(_:next:)`; mutate, retry, inspect, or short-circuit. |
| `TokenProvider` | `actor` — `currentToken()`, `refresh()`, `logOut()`; emits `AuthEvent` to a single consumer. |
| `TokenStore` / `TokenRefreshService` | Storage + refresh seams (app/PalAuth supply impls). |
| `TransientRefreshFailure` | What your refresher throws to keep the session through a temporary failure; `retryAfter` asks for a quiet period. |
| `AuthInterceptor` / `RetryInterceptor` | Take your own rule — `isTokenRejection:`, `shouldRetry:` — in place of their defaults (any 401; `isRetriable`). |

## Defining endpoints (in your Data layer)

```swift
extension Request {
    static func users() -> Request<[UserDTO]> { .init(path: "/users") }
    static func user(id: Int) -> Request<UserDTO> { .init(path: "/users/\(id)") }
    static func createUser(_ dto: CreateUserDTO) -> Request<UserDTO> {
        .init(method: .post, path: "/users", body: .json(dto))
    }
}
```

## Building the client

```swift
let client = HTTPClient(
    baseURL: URL(string: "https://api.example.com")!,
    interceptors: [
        LoggingInterceptor(),
        RetryInterceptor(maxRetries: 2),
        AuthInterceptor(tokenProvider: tokenProvider),
    ]   // outermost first: Logging → Retry → Auth → transport
)

let users = try await client.send(.users())   // -> [UserDTO]
```

## Error handling & layering

`NetworkError` carries the raw server body; decode it on demand in the Data layer, then map to a domain error:

```swift
do {
    return try await client.send(.user(id: id)).toDomain()
} catch let error as NetworkError {
    if let api = error.serverError(as: APIErrorDTO.self) { throw UserError(api) }
    throw UserError.network
}
```

Channel rule: client throws `NetworkError` → repository maps to a **domain error** → presentation maps to `PresentableError`. `.cancelled` is never surfaced. By default `error.isRetriable` drives `RetryInterceptor`: transient transport failures, 5xx, and 429 — whose `Retry-After` hint (integer-seconds form) replaces the exponential backoff, capped at 30 s; your own rule goes in `shouldRetry:` ([Backends with their own conventions](#backends-with-their-own-conventions)). The HTTP method plays no part — a POST is retried like a GET — so give a request that mustn't be sent twice `maxRetries: 0`. Error responses carry their headers (`error.responseHeaders`), so rate-limit and `Location` headers are readable at the call site.

## Per-request options & response metadata

```swift
// A type-ahead search with its own deadline, never retried:
Request<SearchDTO>(
    path: "/search",
    query: ["q": text, "limit": "20"],           // ordered dictionary-literal syntax
    options: RequestOptions(timeout: .seconds(5), maxRetries: 0)
)

// Read the status/headers when they matter (ETag, Location, rate limits):
let (user, response) = try await client.sendWithResponse(.user(id: 1))
let etag = response.headers["ETag"]

// Surface a redirect instead of following it:
let request = Request<EmptyResponse>(path: "/moved", options: RequestOptions(redirectPolicy: .deny))
// -> unacceptableStatus(3xx, …) with error.responseHeaders?["Location"]
```

## Auth refresh (single-flight)

`AuthInterceptor` attaches the access token to every request whose `requiresAuth` is `true` (the default). When a call's token is rejected, it retries the call once with a fresh token from `TokenProvider`, an actor that refreshes **single-flight**: rejections that overlap a refresh share it, a late rejection of the token the last refresh replaced reuses the replacement, and a rejection after the session ended starts nothing. Nothing refreshes ahead of expiry: `AuthTokens.expiresAt` is stored for your own use, never read. What counts as a rejection is your call: any 401 by default, or your own rule ([Backends with their own conventions](#backends-with-their-own-conventions)).

**Wiring (composition root).** The refresher needs a client, and the API client's `AuthInterceptor` needs the `TokenProvider` that holds the refresher. Build two clients, so login and refresh never pass through `AuthInterceptor`:

```swift
let authClient = HTTPClient(baseURL: baseURL, interceptors: [LoggingInterceptor()])   // login + refresh
let tokenStore = KeychainTokenStore()                                                  // PalAuth
let tokenProvider = TokenProvider(store: tokenStore, refresher: SessionRefresher(client: authClient))
let apiClient = HTTPClient(
    baseURL: baseURL,
    interceptors: [
        LoggingInterceptor(),
        RetryInterceptor(maxRetries: 2),
        AuthInterceptor(tokenProvider: tokenProvider),
    ]   // outermost first: Logging → Retry → Auth → transport
)
```

**Your refresher** knows the refresh endpoint, its DTOs, and which failures are temporary:

```swift
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

struct SessionRefresher: TokenRefreshService {
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
```

- **`TransientRefreshFailure` keeps the session:** the tokens stay, nothing is emitted, and the calls waiting on the refresh fail with its `networkError`. Any other error ends the session: the store is cleared and `.loggedOut` emitted. Decide by what your backend answers, not by `isRetriable` alone — a dead refresh token can come back as a 5xx too.
- **`retryAfter:` asks for a quiet period.** `RetryInterceptor`, outside `AuthInterceptor`, retries a call whose refresh failed with a retriable `networkError`, and each attempt tries the refresh again. During a quiet period those attempts fail at once, with no new refresh. Pass the server's `Retry-After` for a 503, and about two seconds for a timeout, which covers the default backoff; leave it out when every attempt should try.
- **The refresh request** sets `requiresAuth: false`, which keeps it out of `AuthInterceptor` on any client. Give it a short `timeout`, and `maxRetries: 0` when refresh tokens rotate: a retry after a lost answer could send one that's already spent.

A call whose rejection can't be fixed fails with the refresh's `networkError` when the session was kept, with its own rejection when the session ended, and with the retried call's answer when the fresh token was rejected too. A call that carried no token, or whose session ended since, fails with its own rejection and starts nothing.

**Login and logout.** Log in by saving the pair your login call returns — `await tokenStore.save(tokens)`: `TokenProvider` reads the store for every request, so the next one carries it. Log out with `await tokenProvider.logOut()`, not `tokenStore.clear()`: it also makes a refresh that's still running drop its result, which clearing the store can't. Switching accounts? Await `logOut()` before saving the next user's pair, or a late call from the old session can be retried with the new user's token.

`logOut()` emits nothing — `.loggedOut` means the session ended by itself. Observe `events` from one place: it hands each event to a single consumer, and buffers those sent before you start. Keep the cleanup in one function for both ends:

```swift
@MainActor
final class AppCoordinator {
    private let tokenProvider: TokenProvider
    private let cache: MemoryCache
    private let analytics: any AnalyticsTracker
    // …

    func logOut() async {                       // the user logs out
        await tokenProvider.logOut()
        await endSession(expired: false)
    }

    func observeSession() async {               // once, from the root view's .task
        for await event in tokenProvider.events where event == .loggedOut {
            await endSession(expired: true)     // the store is already cleared
        }
    }

    private func endSession(expired: Bool) async {
        await cache.clear()
        analytics.reset()
        presentLogin(sessionExpired: expired)
    }
}
```

## Writing an interceptor

```swift
struct HeaderInterceptor: Interceptor {
    func intercept(_ request: TransportRequest, next: Next) async throws(NetworkError) -> NetworkResponse {
        var req = request
        req.urlRequest.setValue("ios", forHTTPHeaderField: "X-Platform")
        return try await next(req)   // call next zero/one/many times; or return to short-circuit
    }
}
```

An interceptor that answers without calling `next` short-circuits the chain, so one placed last is a ready-made test seam for repositories: the real `HTTPClient`, your interceptors and the decoding all run, with no network.

```swift
actor StubTransport: Interceptor {
    private(set) var sent: [TransportRequest] = []
    private let answer: NetworkResponse

    init(answer: NetworkResponse) { self.answer = answer }

    func intercept(_ request: TransportRequest, next: Next) async throws(NetworkError) -> NetworkResponse {
        sent.append(request)
        return answer
    }
}

let stub = StubTransport(answer: NetworkResponse(statusCode: 200, data: Data(#"[{"id":1,"name":"Ada"}]"#.utf8)))
let client = HTTPClient(baseURL: baseURL, interceptors: [stub])
```

The status is checked in the transport, at the chain's inner end, so a stub that *returns* a 500 or a 401 counts as a success and starts no token refresh. To simulate an error status, throw it: `throw .unacceptableStatus(code: 500, data: Data(), headers: [:])`.

## Backends with their own conventions

PalNetworking's defaults — a non-2xx status is an error, any 401 is a token rejection, `error.isRetriable` decides what's retried — are yours to replace. Interceptors you add for this go after `AuthInterceptor` in the list: nearer the transport, where the status is checked, so `AuthInterceptor`'s rule sees what they throw.

**Say which failures mean a rejected token** with `AuthInterceptor(tokenProvider:isTokenRejection:)`. Your rule sees the whole `NetworkError` — status, headers and body — and failures it doesn't accept reach the caller unchanged:

```swift
// An API gateway answers a rejected API key with a 401 of its own; the body tells them apart:
AuthInterceptor(tokenProvider: tokenProvider) { error in
    guard error.statusCode == 401 else { return false }
    let message = error.serverError(as: ErrorBody.self)?.message ?? ""
    return !message.localizedCaseInsensitiveContains("API key")
}

// A backend that answers an expired token with 403:
AuthInterceptor(tokenProvider: tokenProvider) { error in
    error.statusCode == 403 && error.serverError(as: Fault.self)?.code == "TOKEN_EXPIRED"
}
```

A backend that follows RFC 6750 names the reason in its challenge, `WWW-Authenticate: Bearer error="invalid_token"`, which your rule reads from `error.responseHeaders`.

**Turn an answer into an error** when a backend reports errors inside a 200:

```swift
struct ErrorEnvelope: Decodable { let error: String? }

struct ErrorEnvelopeInterceptor: Interceptor {
    func intercept(_ request: TransportRequest, next: Next) async throws(NetworkError) -> NetworkResponse {
        let response = try await next(request)
        let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: response.data)
        guard envelope?.error != nil else { return response }
        throw .unacceptableStatus(code: response.statusCode, data: response.data, headers: response.headers)
    }
}

let client = HTTPClient(baseURL: baseURL, interceptors: [
    LoggingInterceptor(),
    RetryInterceptor(maxRetries: 2),
    AuthInterceptor(tokenProvider: tokenProvider) { $0.serverError(as: ErrorEnvelope.self)?.error == "token_expired" },
    ErrorEnvelopeInterceptor(),
])
```

The error keeps the real status and body, so a token error refreshes like a 401, and a repository reads any other with `serverError(as:)`.

**Turn an error into an answer** when a backend answers 404 for a collection that is merely empty. This one answers every 404 that way, so limit it with a request `flag` when only some endpoints do:

```swift
struct EmptyCollectionInterceptor: Interceptor {
    func intercept(_ request: TransportRequest, next: Next) async throws(NetworkError) -> NetworkResponse {
        do {
            return try await next(request)
        } catch where error.statusCode == 404 {
            return NetworkResponse(statusCode: 200, data: Data("[]".utf8))
        }
    }
}
```

**Retry only what's worth it** with `RetryInterceptor(maxRetries:baseDelay:shouldRetry:)`. By default, a validation error that a backend sends as a 500 is sent three times:

```swift
RetryInterceptor(maxRetries: 2) { error in
    error.isRetriable && error.serverError(as: ErrorCode.self)?.code != "VALIDATION"
}
```

A cancelled call is never retried, whatever your rule says.

## Reachability

Observe the network condition for **UX affordances** — an offline banner, deferring heavy work on expensive paths. Create one `ReachabilityMonitor` at the composition root and inject it:

```swift
let reachability = ReachabilityMonitor()

// SwiftUI reads the observable status directly:
if !reachability.status.isOnline { OfflineBanner() }

// Or react to changes (independent subscription per access; yields the
// current status immediately, then every change — duplicates filtered):
for await status in reachability.statusUpdates { … }
```

`NetworkStatus` carries `isOnline` / `isExpensive` (cellular, hotspot) / `isConstrained` (Low Data Mode). It starts **optimistically online** until the first path update lands, so offline UI never flashes at launch.

**Not a request gate:** attempt requests regardless and let failures surface through the normal error path — preflighting reachability races reality.

## Notes

- Interceptors are **HTTP-level** (raw bytes); typed decoding happens in `send` after the chain.
- The chain currency is `TransportRequest { urlRequest, options }` so per-request flags (`requiresAuth`, `timeout`, `maxRetries`, `redirectPolicy`, custom `flags`) reach interceptors.
- `LoggingInterceptor` logs each exchange's method, URL (`privacy: .private`), status and duration at `.debug`, and a failure's description at `.error` — never headers or bodies, so passwords and tokens in them never reach the log. `NetworkError`'s `description` is redaction-safe by construction (never header values), so logging a caught error can't leak. To read bodies while debugging, use [PalDebugKit](PalDebugKit.md)'s Logs.
- `EmptyResponse` accepts empty bodies; `Data`/`String` responses skip JSON decoding (files/PDFs).
- Query values are emitted form-urlencoded-safe: a literal `+` goes out as `%2B`, so servers that read `+` as a space (virtually all of them) receive the exact value.
- `path` joins the base URL with or without a slash on either side, and is percent-encoded for you: pass raw text (an encoded `%20` would go out as `%2520`) and put queries in `query:` (a `?` in the path is encoded, not parsed). A `/` always separates segments, so a segment can't contain one — not even as `%2F`.
- Redirects are **followed transparently by default** (`URLSession` behavior); opt out per request with `redirectPolicy: .deny` to see the 3xx yourself.
- `.multipart` assembles the whole body **in memory** — fine for form-sized payloads; for large binaries prefer `.file(_:contentType:)`, which streams from disk via an upload task.
- `URLSession` may transparently retry a dropped connection before PalNetworking sees the failure, so servers can log more physical attempts than `RetryInterceptor`'s cap — the cap governs logical attempts.
- The `baseURLProvider` init resolves the base URL per request — the seam behind [PalDebugKit](PalDebugKit.md)'s environment switcher.

See also: [Architecture](../ARCHITECTURE.md) · [PalAuth](PalAuth.md)
