# PalNetworking

> A typed, `async`/`await` networking stack over `URLSession`: generic requests, an interceptor pipeline, typed errors, and single-flight auth refresh. Zero third-party transport. Dependencies: PalCore.

`import PalNetworking`

## What it gives you

- **`Request<Response>`** — a generic value type; endpoints are one-line static factories.
- **`NetworkClient` / `HTTPClient`** — `send(_:)` with **typed throws** (`NetworkError`).
- **Interceptor onion** — composable middleware over `TransportRequest`; ships `Logging`, `Retry`, `Auth`.
- **`TokenProvider`** — an actor doing single-flight 401 refresh (N concurrent 401s → exactly one refresh).
- **Uploads** — multipart and file upload; raw `Data`/`String` responses bypass JSON decoding.

## Key types

| Symbol | Purpose |
|---|---|
| `Request<Response: Decodable & Sendable>` | method, path, query, headers, body, options. |
| `HTTPBody` | `.json`, `.data(_:contentType:)`, `.multipart`, `.file(_:contentType:)`. |
| `NetworkClient` | `func send<Response>(_:) async throws(NetworkError) -> Response`. |
| `HTTPClient` | Concrete client (immutable, `Sendable`); injectable session + decoder/encoder. |
| `NetworkError` | `invalidRequest`, `transport(URLError)`, `unacceptableStatus(code:data:)`, `decoding`, `cancelled`. |
| `Interceptor` / `Next` | `intercept(_:next:)`; mutate, retry, inspect, or short-circuit. |
| `TokenProvider` | `actor` — `currentToken()`, `refresh()`; emits `AuthEvent`. |
| `TokenStore` / `TokenRefreshService` | Storage + refresh seams (app/PalAuth supply impls). |

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

Channel rule: client throws `NetworkError` → repository maps to a **domain error** → presentation maps to `PresentableError`. `.cancelled` is never surfaced. `error.isRetriable` drives `RetryInterceptor` (transport failures + 5xx/429).

## Auth refresh (single-flight)

```swift
let tokenProvider = TokenProvider(store: keychainTokenStore, refresher: myRefreshService)
// On 401, AuthInterceptor awaits tokenProvider.refresh() once and retries.
// Observe logout to route to login:
for await event in tokenProvider.events where event == .loggedOut {
    coordinator.presentLogin()
}
```

You supply a `TokenRefreshService` (`refresh(using:)` — knows your refresh endpoint + DTOs). PalAuth supplies a Keychain-backed `TokenStore` (see [PalAuth](PalAuth.md)). The refresh request sets `requiresAuth = false` (via `RequestOptions`) so it skips `AuthInterceptor` — no recursion.

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
- The chain currency is `TransportRequest { urlRequest, options }` so per-request flags (`requiresAuth`, custom `flags`) reach interceptors.
- `LoggingInterceptor` redacts auth headers always; logs bodies only at `.debug`; uses `privacy: .private` for dynamics.
- `EmptyResponse` accepts empty bodies; `Data`/`String` responses skip JSON decoding (files/PDFs).
- The `baseURLProvider` init resolves the base URL per request — the seam behind [PalDebugKit](PalDebugKit.md)'s environment switcher.

See also: [Architecture](../ARCHITECTURE.md) · [PalAuth](PalAuth.md)
