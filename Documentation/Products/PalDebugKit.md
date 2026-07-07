# PalDebugKit

> A shake-to-debug suite — network logs, environment switching, and response mocking — in an overlay above any app state. Dependencies: PalCore, PalNetworking, PalPersistence (not PalDesignSystem; the debug UI is self-contained). The one Pal product that touches UIKit (contained + gated `#if canImport(UIKit)`), since shake detection and above-everything overlay aren't expressible in pure SwiftUI.

`import PalDebugKit`

## What it gives you

- **Logs** — a live, searchable network inspector: method, URL, status, real timing, redacted headers, body preview. A `DebugInspectorInterceptor` (outermost) feeds an observable, capped ring-buffer store (session-only, never persisted).
- **API switcher** — change the active environment at runtime; the next request resolves the new base URL with no client rebuild. App-defined `APIEnvironment`s, plus user-added custom entries.
- **Mocks** — stub any captured call: tap it (body auto-seeded from the response), edit status/body, toggle it. A `MockInterceptor` short-circuits the chain; mocked exchanges still appear in Logs.

## Wiring (composition root)

Everything is gated behind **your app's** `DEBUGKIT` compilation flag so release builds carry no wiring.

```swift
#if DEBUGKIT
PalDebugTools.shared.enable(environments: [
    APIEnvironment(name: "Production", baseURL: prodURL),
    APIEnvironment(name: "Staging", baseURL: stagingURL),
])
let interceptors: [any Interceptor] = [
    PalDebugTools.shared.inspectorInterceptor,   // outermost
    PalDebugTools.shared.mockInterceptor,
    LoggingInterceptor(), RetryInterceptor(), AuthInterceptor(tokenProvider: tokenProvider),
]
let client = HTTPClient(
    baseURLProvider: { EnvironmentResolver.baseURL(for: .default, default: prodURL) },
    interceptors: interceptors
)
#else
let client = HTTPClient(baseURL: prodURL, interceptors: [LoggingInterceptor(), RetryInterceptor()])
#endif
```

Order is **inspector → mock → Logging → Retry → Auth → transport**, so mocked calls are logged for free and the inspector captures request start + real timing.

## Presenting + reacting to switches

```swift
// On your root view — shake opens the overlay menu:
rootView
    #if DEBUGKIT
    .onShake { PalDebugTools.shared.present() }
    .task {
        for await change in PalDebugTools.shared.environmentChanges {
            // your reset: cancel in-flight work, clear tokens + cache, reset navigation
        }
    }
    #endif
```

The base URL resolves per request through `EnvironmentResolver` (synchronous, off the main actor); selecting a new environment persists it and broadcasts `environmentChanges`. **In-flight cancellation is app-owned** — your reset on the event tears down the work; the client stays immutable.

## Gating (default-OFF, triple fenced)

1. **Runtime flag** — `PalDebugTools` is OFF until `enable(…)`; `present()` is inert otherwise.
2. **App compilation flag `DEBUGKIT`** — wrap the wiring in `#if DEBUGKIT`, defined only in the app configurations that should carry tools (e.g. Debug + a Beta config). App Store config never defines it.
3. **Data fence** — you pass a per-configuration environment list, so release has nothing to switch to.

Full opt-out is absolute: an app that never links PalDebugKit has zero footprint.

## Notes

- **Custom tabs:** `present { /* your SwiftUI tabs */ }` appends app modules via a `@ViewBuilder` slot (no type-erased registry, no `AnyView`).
- **Logs are session-only** (in-memory ring buffer); **mocks, custom environments, and the selected environment persist** via typed `DefaultsKey`.
- `environmentChanges` hands out an **independent subscription per access** — observe from several tasks or resubscribe freely.
- Mock bodies seed from the captured **preview** (capped ~20 KB) — a very large response seeds a truncated stub; paste the full body if you need it.
- Shake rides the UIKit responder chain — while a text field has the keyboard up, the shake may not reach the detector; dismiss the keyboard first.
- The debug menu UI is developer-facing and intentionally **not localized** (unlike PalDesignSystem/PalPresentation).
- **Fully-local apps: skip this product** — it is deliberately network-centric (the Logs/API/Mocks triad is its value). A small app-side `#if DEBUG` settings section covers local debug needs (seeding, state resets).
- **Not in v1** (additive later): Flags viewer/overrides, Saved Logs export, language override, version spoofing.

See also: [Architecture](../ARCHITECTURE.md) · [PalNetworking](PalNetworking.md) · [Getting Started](../GettingStarted.md)
