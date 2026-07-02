# PalAnalytics

> A provider-agnostic analytics seam: your code tracks events through one protocol, SDKs stay at the composition root. Dependencies: PalCore.

`import PalAnalytics`

## What it gives you

- **`AnalyticsTracker`** — `track(_:)`, `identify(userID:)`, `setUserProperty(_:for:)`, `reset()`.
- **`AnalyticsEvent`** — `name` + `[String: AnalyticsValue]`; apps define events as static factories. Initializer: `AnalyticsEvent(name: String, parameters: [String: AnalyticsValue] = [:])`.
- **`AnalyticsValue`** — `.string` / `.int` / `.double` / `.bool` (literal-expressible).
- **Shipped impls** — `NoOpAnalyticsTracker` (default), `ConsoleAnalyticsTracker` (via LoggerFactory), `CompositeAnalyticsTracker` (fan-out to N providers).

## Usage

```swift
import PalAnalytics

// Define events as static factories (compile-time safe, discoverable):
extension AnalyticsEvent {
    static func userSignedIn(method: String) -> AnalyticsEvent {
        .init(name: "user_signed_in", parameters: ["method": .string(method)])
    }
}

// Track from ViewModels (never Views, never repositories):
tracker.track(.userSignedIn(method: "apple"))
tracker.identify(userID: user.id)
tracker.reset()   // on logout — pairs with AuthEvent.loggedOut
```

## Wiring providers (composition root)

```swift
#if DEBUG
let tracker: any AnalyticsTracker = ConsoleAnalyticsTracker()
#else
let tracker: any AnalyticsTracker = CompositeAnalyticsTracker([
    FirebaseAnalyticsTracker(),   // your app-side adapter conforming to AnalyticsTracker
    AmplitudeTracker(),
])
#endif
```

The default registration is `NoOpAnalyticsTracker` — projects without analytics carry zero SDK and zero config. Provider SDKs are imported **only** at the composition root; swap providers in one line.

## Notes

- Concrete SDK adapters live in the **app**, conforming to `AnalyticsTracker`. The foundation ships no SDK.
- `AnalyticsValue` conforms to the literal protocols, so `["count": 3, "ok": true]` works directly.

See also: [PalFeatureFlags](PalFeatureFlags.md) · [Architecture](../ARCHITECTURE.md)
