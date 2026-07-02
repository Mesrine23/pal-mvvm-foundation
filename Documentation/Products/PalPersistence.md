# PalPersistence

> Type-safe storage: Keychain, UserDefaults, and an in-memory TTL cache — all driven by typed keys with uniform verbs. Dependencies: PalCore.

`import PalPersistence`

## What it gives you

- **`KeychainService`** — throwing, typed Keychain access for secrets.
- **`UserDefaultsService`** — plist-native key/value storage.
- **Typed keys** — `KeychainKey<Value>` / `DefaultsKey<Value>` / `CacheKey<Value>`: the value type travels with the key, so reads and writes are compile-time checked. Initializers: `DefaultsKey(_ name: String, default: Value? = nil)` · `KeychainKey(service: String, account: String, accessibility: KeychainAccessibility = .afterFirstUnlock)` · `CacheKey(_ name: String, ttl: Duration)`.
- **`MemoryCache`** — an actor with passive per-key TTL; **memory-only by policy** (nothing survives an app launch).

All three stores share the same verbs: **`get` / `set` / `delete`** (Keychain also `throws`; the one justified asymmetry — Keychain genuinely fails).

## The law: apps own their keys

No app keys ship in the foundation. Declare yours as static extensions:

```swift
extension DefaultsKey where Value == Bool {
    static var hasSeenOnboarding: DefaultsKey<Bool> { .init("hasSeenOnboarding", default: false) }
}
extension KeychainKey where Value == AuthTokens {
    static var authTokens: KeychainKey<AuthTokens> { .init(service: "com.app", account: "tokens") }
}
extension CacheKey where Value == [User] {
    static var users: CacheKey<[User]> { .init("users", ttl: .seconds(60)) }
}
```

## Usage

```swift
import PalPersistence

// UserDefaults — non-throwing, plist-native types stored directly
let defaults = UserDefaultsService()
defaults.set(true, for: .hasSeenOnboarding)
let seen = defaults.get(.hasSeenOnboarding) ?? false   // default applies when unset

// Keychain — throwing, typed errors
let keychain = KeychainService()
try keychain.set(tokens, for: .authTokens)
let saved = try keychain.get(.authTokens)              // nil ONLY when not found
try keychain.delete(.authTokens)

// MemoryCache — repository-level cache-aside
let cache = MemoryCache()
await cache.set(users, for: .users)                    // TTL from the key (or override per set)
let cached = await cache.get(.users)                   // nil if absent OR expired (passive)
await cache.clear()                                     // e.g. on logout
```

## Cache-aside pattern (recommended repository usage)

```swift
func getUsers(forceRefresh: Bool = false) async throws -> [User] {
    if !forceRefresh, let cached = await cache.get(.users) { return cached }
    let fresh = try await client.send(.users()).map(\.toDomain)
    await cache.set(fresh, for: .users)
    return fresh
}
```

## Notes

- **`MemoryCache` is memory-only by design** — no disk persistence, no stale sensitive data on disk, no cross-launch surprises. Pairs with `ViewState.loading(previous:)` for stale-while-revalidate.
- **Passive TTL** — expiry is evaluated on `get` (delete-on-read). No sweepers, no timers, lifecycle-immune.
- `KeychainKey` sets `kSecAttrAccessible` explicitly (default `.afterFirstUnlock`, configurable via `KeychainAccessibility`).
- `KeychainError` distinguishes not-found (returns `nil`) from `encodingFailed` / `decodingFailed` / `unexpectedStatus(OSStatus)`.
- Ships `PrivacyInfo.xcprivacy` (UserDefaults required-reason API) for App Store compliance.
- **Local relational data (SwiftData/Core Data)** is *not* part of PalPersistence — it stays zero-dependency. Model it app-side behind a repository; see the SwiftData adoption note in [Architecture](../ARCHITECTURE.md#adopting-pal-in-an-existing-app).

See also: [PalAuth](PalAuth.md) (token-store glue) · [Getting Started](../GettingStarted.md)
