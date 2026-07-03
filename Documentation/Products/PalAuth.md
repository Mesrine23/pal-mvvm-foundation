# PalAuth

> Token storage glue (Keychain ⇄ Networking) plus biometric gating (Face ID / Touch ID) behind one typed call. Dependencies: PalCore, PalNetworking, PalPersistence (+ the system `LocalAuthentication` framework).

`import PalAuth`

## What it gives you

- **`KeychainTokenStore`** — implements PalNetworking's `TokenStore` (`tokens()` / `save(_:)` / `clear()`) backed by PalPersistence's `KeychainService` + a `KeychainKey<AuthTokens>`. It exists so Networking stays storage-agnostic and Persistence stays auth-agnostic; the dependency on both lives only here.
- **`BiometricAuthenticator`** — Face ID / Touch ID / Optic ID with typed outcomes and errors; cancellation is an outcome, never an error.

## Usage

```swift
import PalAuth

let store = KeychainTokenStore(
    keychain: KeychainService(),
    key: .authTokens          // ships a convenience KeychainKey<AuthTokens>; override if you prefer your own
)

let tokenProvider = TokenProvider(store: store, refresher: myRefreshService)
```

Wire `tokenProvider` into `AuthInterceptor` (see [PalNetworking](PalNetworking.md)). On logout, `store.clear()` is called for you when the session ends.

## Biometrics

```swift
let biometrics = BiometricAuthenticator()

// Availability drives the affordance (a Face ID button, a settings toggle):
if biometrics.availableBiometry != .none { showBiometricUnlock() }

switch try await biometrics.authenticate(reason: String(localized: "Unlock your vault")) {
case .authenticated:     unlock()
case .cancelled:         break                       // never an error — do nothing
case .fallbackRequested: showPasswordSheet()         // your fallback path
}
// Thrown BiometricErrors (.unavailable / .notEnrolled / .lockedOut / .failed) → .appAlert
```

- **A fresh `LAContext` per evaluation** — contexts cache their state; reuse is the classic stale-Face-ID pitfall. Pal owns that detail.
- `allowingPasscodeFallback: true` lets the **system** offer the device passcode (then `fallbackRequested` never occurs); `fallbackTitle` renames the fallback button. Reason and titles are app values (localized by you).
- Face ID needs `NSFaceIDUsageDescription` in the **app's** Info.plist.
- Cancellation (`userCancel`/`systemCancel`/`appCancel`) returns `.cancelled` — the foundation's cancellation rule.

## Notes

- `AuthTokens { accessToken, refreshToken, expiresAt }` lives in PalNetworking (so the auth machinery can use it); PalAuth only bridges it to storage.
- Want a non-Keychain store (e.g. in-memory for tests)? Conform your own type to `TokenStore` — you do not need this product for that.

See also: [PalNetworking](PalNetworking.md) · [PalPersistence](PalPersistence.md)
