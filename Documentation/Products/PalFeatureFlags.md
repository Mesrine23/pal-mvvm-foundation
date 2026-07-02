# PalFeatureFlags

> A simple, synchronous feature-flag seam: typed flags with safe defaults, read from memory. Dependencies: PalCore.

`import PalFeatureFlags`

## What it gives you

- **`FeatureFlagsProvider`** — `isEnabled(_ flag: FeatureFlag) -> Bool` (synchronous).
- **`FeatureFlag`** — `key` + `defaultValue` (so a missing provider/value degrades safely). Initializer: `FeatureFlag(key: String, defaultValue: Bool = false)`.
- **Shipped impls** — `InMemoryFeatureFlagsProvider` (seed once, read synchronously), `NoOpFeatureFlagsProvider` (defaults only).

## Usage

```swift
import PalFeatureFlags

// Declare flags as static factories with a safe default:
extension FeatureFlag {
    static var newCheckout: FeatureFlag { .init(key: "new_checkout", defaultValue: false) }
}

// Runtime model: fetch once at app start → seed memory → read synchronously everywhere.
let flags = InMemoryFeatureFlagsProvider()
flags.update(["new_checkout": true])           // seed from your remote config / RemoteConfig at launch

if flags.isEnabled(.newCheckout) { showNewCheckout() }
```

`InMemoryFeatureFlagsProvider` also supports `set(_:forKey:)` and seeding via `init(values:)`. No flags support at all? Register `NoOpFeatureFlagsProvider` — every read returns the flag's `defaultValue`.

## Notes

- Bool-only by design (`isEnabled`); keep flags simple.
- The "fetch once at start → synchronous reads from memory" model mirrors the memory-only cache philosophy — no `async` at call sites.
- Remote adapters (LaunchDarkly, RemoteConfig, …) live in the **app**, conforming to `FeatureFlagsProvider` or feeding `update(_:)`.

See also: [PalAnalytics](PalAnalytics.md) · [Architecture](../ARCHITECTURE.md)
