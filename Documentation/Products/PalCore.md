# PalCore

> The Foundation-only bedrock every other product builds on. **No SwiftUI** — so Domain code can depend on it safely. Dependencies: none.

`import PalCore`

## What it gives you

- **Logging** — an `os.Logger` factory, opt-in (you log only where you call it).
- **Curated Foundation extensions** — the small, app-agnostic conveniences worth sharing. (Validation *rules* are app values and deliberately absent — e.g. there is no `isValidEmail`.)
- **Async utilities** — `Debouncer` and `withTimeout`.
- **`AppInfo`** — version/build/bundle id + build-context detection.
- **`AppLanguage`** — read available/current languages and override the app language without bundle swizzling.

## Key types

| Symbol | Purpose |
|---|---|
| `LoggerFactory.make(category:)` | Returns an `os.Logger` (subsystem = main bundle id). |
| `Debouncer` | Task-based debounce for search-as-you-type and bursty events. |
| `withTimeout(_:operation:)` | Races async work against a `Duration` deadline; throws `TimeoutError`. Only as prompt as the work's cancellation handling — it waits for a blocking call to return, so it can't rescue one that hangs. |
| `AppInfo` | `current` snapshot: `version`, `build`, `bundleId`, `displayName`; `isDebug`, `isSimulator`. |
| `AppLanguage` | `available`, `current`, `setOverride(_:)`, `overrideRequiresRestart`. |

### Extensions

- **String** — `trimmed`, `isBlank`, `nilIfEmpty`, `isNumber`.
- **Array** — `appendSafe(_:)` (ignores `nil`), `removingDuplicates()` (order-preserving, `Element: Hashable`).
- **Collection** — `isNotEmpty`, `subscript(safe:)`.
- **Date** — `init?(iso8601:)`, `iso8601String`, `isSameDay(as:calendar:)`.
- **Double** — `rounded(to:)`.
- **Optional** — `orEmpty` (for `String?` / range-replaceable collections).

## Usage

```swift
import PalCore

// Logging — opt-in, category per feature
let log = LoggerFactory.make(category: "Checkout")
log.debug("Cart recalculated: \(items.count, privacy: .public) items")

// Never log secrets — use privacy: .private for dynamic values (clean-code rule 5)
log.info("Signed in user \(userID, privacy: .private)")

// Debounce a search field
let debouncer = Debouncer(duration: .milliseconds(300))
func searchChanged(_ text: String) {
    debouncer.call { viewModel.search(text) }
}

// Bound a slow call
let result = try await withTimeout(.seconds(10)) {
    try await slowOperation()
}

// Build context
if AppInfo.isDebug { /* dev-only affordance */ }
let footer = "v\(AppInfo.current.version) (\(AppInfo.current.build))"
```

## Notes

- Logging is a **passive utility** — no foundation package forces logs. `LoggingInterceptor` (PalNetworking) is included per app, not automatic.
- Extensions grow organically through dogfooding; keep additions app-agnostic.
- `AppInfo` distribution detection (TestFlight/App Store) is intentionally not here — the modern API needs StoreKit, which would breach Core's Foundation-only rule. It is purely additive later, where the first consumer lives.

See also: [Getting Started](../GettingStarted.md) · [Architecture](../ARCHITECTURE.md)
