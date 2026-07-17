# Changelog

Consumer-facing changes per release, newest first — **the** place for users and agents to catch up on what's landed. Versions are git tags (SemVer; the compatibility policy lives in [CONTRIBUTING](CONTRIBUTING.md)); every entry also exists as a [GitHub Release](https://github.com/Mesrine23/pal-mvvm-foundation/releases). Full API docs: [hosted DocC reference](https://mesrine23.github.io/pal-mvvm-foundation/).

## [Unreleased] — targeting 1.5.0

A networking-hardening batch, driven by an end-to-end validation of PalNetworking against a purpose-built local mock backend (every capability exercised through real HTTP, assertions journal-verified server-side).

### Fixed
- **Query values containing a literal `+` now reach servers intact.** `URLComponents` leaves `+` unencoded (legal per RFC 3986), but real-world servers decode queries as form-urlencoded where `+` means space — so `q=a+b` silently arrived as `a b`. `HTTPClient` now emits `%2B`.
- A scheduling-order flake in the `PagedLoader` re-trigger test (the test assumed spawned tasks start in FIFO order).

### Added
- **`NetworkClient.sendWithResponse(_:)`** — the decoded value *plus* the `NetworkResponse` (status, headers) for call sites that need `ETag`, `Location`, or rate-limit headers; ships with a default implementation so existing conformances keep compiling.
- **Per-request options** on `RequestOptions`: `timeout` (applied to `URLRequest.timeoutInterval`), `maxRetries` (overrides `RetryInterceptor`'s cap; `0` = never retry — non-idempotent POSTs), and `redirectPolicy`.
- **`RedirectPolicy`** — `.follow` (default) or `.deny`, which surfaces the 3xx as `unacceptableStatus` with its `Location` header readable instead of following it.
- **429 handling** — `isRetriable` now includes 429, and `RetryInterceptor` honors a `Retry-After` hint (integer-seconds form) in place of the exponential backoff, capped at 30 s.
- **`NetworkError` accessors** — `statusCode`, `urlError`, `responseHeaders`, `retryAfter` — plus a redaction-safe `CustomStringConvertible` (header values never appear in `String(describing:)`, keeping error logs leak-free).
- **`Request` dictionary-literal query initializer** (`KeyValuePairs` — order-preserving): `Request(path: "/search", query: ["q": text, "limit": "20"])`.
- **`MultipartPart.text(name:value:)` / `.file(name:filename:contentType:data:)`** factories.
- **`PagedLoader.performLoadMore()`** — the awaitable sibling of `loadMore()` for tests, tools, and prefetching.
- **`Loader.reset()`** — cancel *and* return to `.idle`; the affordance behind a user-facing Cancel button (`cancel()` alone keeps the state, stranding a visible spinner).

### Breaking (pre-adoption)
- `NetworkError.unacceptableStatus(code:data:)` gained a third associated value: `headers: [String: String]`. Pattern matches need one more `_`. Shipped in a minor **deliberately**: PalNetworking has zero adopters today, so a major bump would version-tax an unused surface — recorded in the deviations log. The `api-stability` gate is expected red on this branch and re-baselines at the release tag.
- `RequestOptions.init` was extended in place (new defaulted parameters) rather than duplicated — call sites are source-compatible; only the exact old signature is gone.

## [1.4.1] — 2026-07-07

### Documentation
- Editorial pass on the release notes and deviations log. No API or behavior change.

## [1.4.0] — 2026-07-07

An adoption-feedback batch.

### Added
- `ThemeColors.surfaceElevated` — the tone for floating chrome (sheets, alerts, toasts) one level above `surface`; **defaults to `surface`** so existing themes render identically. The alert and toast cards now draw from it.
- `Color(hex:)` — compile-checked `Color(hex: 0xF3F1EC)` and failable `Color(hex: "#RRGGBB")` / `"#RRGGBBAA"` for design-token layers.
- `FlowLayout` — wrapping chip/tag rows (PalDesignSystem).

### Documentation
- `PresentableError(from:)` surfaced for ACTION paths (it always existed — the guide now shows it).
- New patterns: **editor screens** (Loader fetch + synchronous draft + ordered snapshot saves) · **optional content** (model absence as a domain case, not `Loader<Value?>`) · **reload-on-return** · a **fully-local app recipe**.
- `EmptyStateView`'s full signature; the `.textStyle`-requires-`import PalDesignSystem` note; editable-route-payload "seed" pattern; `@ModelActor` granularity guidance.

### Evolution note
- The pre-1.4 `ThemeColors.init` is kept verbatim beside the new one — inserting a defaulted parameter is source-compatible but removes the old signature (the `api-stability` gate's first real catch).

## [1.3.1] — 2026-07-03

### Fixed
- `PalNotifications` now builds on Xcode 16 / Swift 6.1 as well as Xcode 26 (`@preconcurrency import UserNotifications` — the framework isn't concurrency-audited on older SDKs). No API change.

## [1.3.0] — 2026-07-03

### Added
- `ReachabilityMonitor` + `NetworkStatus` (PalNetworking) — network condition for UX affordances (offline banners); observable `status` + broadcast `statusUpdates`; deliberately **not** a request preflight gate.
- `BiometricAuthenticator` (PalAuth) — Face ID / Touch ID / Optic ID behind one typed call; cancellation and the fallback button are **outcomes**, never errors; fresh `LAContext` per evaluation.

## [1.2.0] — 2026-07-03

### Added
- **PalWeb** — the 12th product: `WebScreen` (a `WKWebView` driving `WebPageModel`'s `ViewState`, live title/progress/history), the app-supplied navigation policy (`allow` / `cancel` / `openExternally`), and `ExternalLinkOpener` for non-View contexts. OAuth guidance: `ASWebAuthenticationSession` app-side, never an embedded web view.

## [1.1.0] — 2026-07-03

### Added
- Skeleton loading: `.skeleton(when:)` / `.shimmering(active:)`.
- Scroll observation: `.scrollObservationTarget()` + `.onScrollOffsetChange` / `.onReachedBottom(threshold:)`.
- `PagedLoader<Item, Cursor>` + `Page` — pagination machinery; the documented trigger is the trailing footer row **outside the `ForEach`**, firing on appearance.
- `AppToast` + `.appToast($toast)` — the non-blocking confirmation half of the ACTION channel.

## [1.0.0] — 2026-07-02

The public API contract begins: all 11 products of the 1.0 line (Core, Persistence, Networking, Auth, Presentation, Navigation, DesignSystem, Analytics, FeatureFlags, DebugKit, Notifications) on Swift 6 strict concurrency, iOS 17+, zero external dependencies. From here: additive → minor, fix → patch, breaking → major with deprecation-first — enforced in CI.

## Pre-1.0

The `v0.1.0 … v0.13.0` build-out is chronicled in [CONTRIBUTING](CONTRIBUTING.md)'s phase log and deviations log.
