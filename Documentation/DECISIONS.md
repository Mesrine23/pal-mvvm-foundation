# Pal — Engineering Decisions

> **Why Pal is shaped the way it is** — the architectural decisions behind the foundation, for the engineers and agents who build on it and contribute to it.
> A **living document, open to discussion.** Pal is built to be scalable and maintainable, so these decisions are proposals to improve on, not dogma — propose changes rather than drifting silently. If code or docs contradict this file, treat this file as the intended design and reconcile by raising a change.
>
> New here? Start with **[Getting Started](GettingStarted.md)**, browse the **[per-product guides](Products/)**, and read **[Architecture](ARCHITECTURE.md)** for structure. Implementation status and the deviations log live in **[CONTRIBUTING](../CONTRIBUTING.md)**.

## 1. Identity & goals

- **Pal** is a reusable, state-of-the-art iOS foundation owned by Panagiotis "Pal" Palamidas.
- Delivered as **one Swift Package with multiple library products**, consumed by apps via SPM. Apps are created normally in Xcode and add Pal as a dependency, pinned per app to a version/branch/commit.
- The foundation ships **mechanisms**; apps ship **values** (concrete endpoints, strings, brand tokens, storage keys, analytics events, environments, validation rules). This law governs every API decision.
- The in-repo `Example/` app (local path dependency) is the dogfooding host: previews, manual testing, demo of the canonical patterns.

## 2. Toolchain & build decisions

| Decision | Value |
|---|---|
| Language mode | **Swift 6, strict concurrency**, from the first line |
| swift-tools-version | **6.0** (not bleeding edge; newer features later behind `#if compiler`) |
| Deployment floor | **iOS 17** for the package (Example app may target latest) |
| External dependencies | **ZERO.** Swinject appears only app-side (Example app + docs snippets) |
| Versioning | SemVer via git tags — **`v1.0.0` shipped 2026-07-02** (all 11 products, two dogfood apps). Breaking = major with deprecation-first (§19), enforced by the `api-stability` CI gate; consumers pin tags with `from:` |
| Repo visibility | Public (MIT) |
| License | **MIT** |
| CI | GitHub Actions on push/PR: build+test on **both toolchain edges** (`macos-15` = Xcode 16 consumer floor · `macos-26` = latest) + the `api-stability` gate; a `Docs` workflow publishes DocC to GitHub Pages on release tags |

## 3. Package map & dependency DAG

Products and their **only allowed** dependencies (downward only, enforced in `Package.swift`):

| Product | Depends on |
|---|---|
| `PalCore` | — |
| `PalPersistence` | Core |
| `PalNetworking` | Core |
| `PalAuth` | Core, Networking, Persistence |
| `PalPresentation` | Core |
| `PalNavigation` | — (add Core only if genuinely needed) |
| `PalDesignSystem` | Core, Presentation |
| `PalAnalytics` | Core |
| `PalFeatureFlags` | Core |
| `PalDebugKit` | Core, Networking, Persistence (NOT DesignSystem — debug UI is self-contained) |
| `PalNotifications` | Core (+ the system `UserNotifications` framework) |
| `PalWeb` | Core, Presentation (+ the system `WebKit` framework) |
| `Example` app | everything + Swinject (app-side) |

Rules:
- Every target declares **all modules it directly imports** — never rely on transitive visibility.
- UI-bearing packages are never imported by lower ones. `PalCore` imports Foundation only — **no SwiftUI in Core** (generic SwiftUI helpers live in `PalDesignSystem`).
- `PalTestSupport` joins in Phase 11 with broad test coverage.

## 4. Naming conventions (SCOPED — do not "fix" this)

- **App-layer seams** use explicit suffixes (matches the owner's established style):
  - Use cases: `‹Verb›‹Entity›UseCaseProtocol` → `‹Verb›‹Entity›UseCase`. Exactly **one** method: `execute(...)`. No marker base protocol; each use-case protocol stands alone.
  - Repositories: `‹Entity›RepoProtocol` → `‹Entity›Repository` (deliberate asymmetry). Entity-based by default; capability-based (`CheckoutRepository`-style) when the seam is a capability.
  - Navigation delegates: `‹Screen›NavigationDelegate` with intent-named methods (`showUserDetail(_:)`).
- **Foundation public API uses standard Swift naming** per Swift API Design Guidelines: `NetworkClient`, `TokenStore`, `Interceptor`, `Routable`, `KeychainService`…
  **GUARD: do NOT rename foundation protocols to add `…Protocol` suffixes** (e.g. `TokenStore` must never become `TokenStoreProtocol`). The suffix convention is app-layer only.
- One primary type per file, named after the type — a protocol may share a file with its single conforming implementation. Extensions: `Type+Feature.swift`.
- Storage/cache APIs share uniform verbs: `get` / `set` / `delete`.

## 5. Clean-code rules (binding for ALL agents and humans)

1. **No user-facing string literals in Views/ViewModels** — String Catalog keys via `String(localized:)`/generated symbols only.
2. **No implementation comments** — self-documenting naming; sole exception: a genuinely non-obvious constraint/workaround, explaining WHY never WHAT. No commented-out code. `// MARK:` section dividers permitted. **`///` documentation comments are REQUIRED on every public symbol** (Quick Help/DocC). DocC catalog considered by 1.0.
3. Binding naming conventions per §4.
4. **No force-unwraps / `try!` / `as!`** — sole exception: DI resolution at the app's composition root (fail-fast by design).
5. **No `print()`** — `LoggerFactory` only (opt-in). **Never log secrets:** Authorization/auth headers always redacted; request/response bodies at `.debug` level only; `privacy: .private` interpolation for dynamic values.
6. **No `AnyView`** or type-erasure workarounds.
7. No magic numbers in UI — theme tokens for spacing/radii where DesignSystem is used.
8. **One primary type per file**, named after it — a protocol may be co-located with its single conforming implementation (e.g. `FetchUsersUseCaseProtocol` + `FetchUsersUseCase` in `FetchUsersUseCase.swift`). Extensions as `Type+Feature.swift`.
9. Explicit access control; smallest public surface.
10. Layer rules: Views never touch clients/repos; ViewModels import Domain + PalPresentation — plus PalDesignSystem **solely to own `AppAlert`/`AppToast` state** (ruled 2026-07-07: the ACTION-channel values are ViewModel state by design and the import is the blessed shape — moving the types behind typealiases would trip both the `api-stability` gate and `MemberImportVisibility` apps; the chrome stays in Views); DTO↔entity mapping lives in Data; dependency arrows point inward.
11. Swift 6 hygiene: no `@unchecked Sendable` without written justification; `@MainActor` ViewModels; actors for shared mutable state.
12. Errors are never silently swallowed; mapped at boundaries (`NetworkError` → domain error → `PresentableError`); cancellation never surfaces to users.
13. **Reference types are `final` by default** — every class is `final` unless explicitly designed for subclassing (enables static dispatch, signals intent). Structs, enums, and actors need no annotation.

## 6. Architecture

- **MVVM + Coordinators** with Clean-style layering: **Presentation / Domain / Data**.
- Dependency direction: everything points inward to Domain. Domain is pure Swift (no networking, no UI, no Codable on entities).
- **Canonical vertical slice** (the reference pattern for every feature):
  - **Domain** (pure): entity (`User`) · repo protocol (`UsersRepoProtocol`) · use case (`FetchUsersUseCase: FetchUsersUseCaseProtocol`, single `execute`).
  - **Data** (Domain + PalNetworking): `UserDTO: Decodable` + `toDomain()` mapping · `Request` factories live HERE (return `Request<…DTO>`) · `UsersRepository` calls `NetworkClient.send`, maps DTO→entity.
  - **Presentation** (Domain only): `@MainActor @Observable` ViewModel holding one or more `Loader<…>` (each drives a `ViewState`); SwiftUI View switches on `viewModel.‹loader›.state`.
  - **Composition root** (app shell): wires client → repo → use case → ViewModel.
- **Multi-call screens:** a composing use case returns a composite content model; parallel via `async let`, sequential `await` where data-dependent; structured concurrency auto-cancels siblings on failure. ViewModel stays a one-line `loader.load {}`.
- **Partial-failure screens:** composite model fields typed `Result<Value, PresentableError>`; the use case wraps optional topics; View renders per-topic content or an inline `SectionErrorView`. Critical call still throws → whole screen fails. Default retry re-runs the whole composition.
- **Delegation (child → owner):** when a child must report back to the owner that presents it (navigation, flow completion), use a `‹Context›Delegate` — `@MainActor`, `AnyObject`, held **weak**, intent-named methods. It is the default over passing closures or `Binding`s upward. A **closure** suffices for a single one-shot callback; an **`AsyncStream`** carries broadcast events (e.g. `AuthEvent`), not a delegate. Navigation seams keep the `‹Screen›NavigationDelegate` name (§4).
- **Local mutation (re-fetch after write):** a local store has no `@Query`; after a write through the repository, re-fetch to reflect the change (coordinator → list VM `refresh()`). Keeps one source of truth and the read path unchanged.

## 7. DI & composition (app-side pattern — NOT in the foundation)

- Pattern = **constructor injection everywhere**; the app's composition root wires dependencies. Swinject (native `Assembly`/`Assembler`, single root container) is the demonstrated approach in `Example/`; plain manual wiring is the documented alternative.
- Registration against protocols (`…RepoProtocol → …Repository`, `…UseCaseProtocol → …UseCase`). Object scopes: transient/graph default; `.container` for deliberate singletons (e.g. `NetworkClient`).
- **Factories** (app-side, per feature) resolve use cases and constructor-inject ViewModels. The factory is the only place that touches the container. `resolver.resolve(X.self)!` force-unwrap is the sanctioned fail-fast exception.
- Swift 6 notes: composition root + factories are `@MainActor`; `@preconcurrency import Swinject` is expected.
- No `@Inject` property wrapper, no global `Resolver.shared`, no service locator.

## 8. PalCore

- `LoggerFactory.make(category:)` → `os.Logger` (subsystem = main bundle id). Logging is **opt-in**; no protocol abstraction.
- Curated Foundation-only extensions: String (`isBlank`, `nilIfEmpty`, `trimmed`, `isNumber` — **no `isValidEmail`**: validation rules are app values) · Collection (`subscript(safe:)`, `isNotEmpty`) · Array (`removingDuplicates()` order-preserving, `appendSafe`) · Date (`Date(iso8601:)`, `isSameDay(as:)`, thin `FormatStyle` conveniences) · Double (`rounded(to:)`) · Optional (`orEmpty` for String?/Collection?). Extensions grow organically via dogfooding.
- Async utilities: `Debouncer` (Task-based) · `withTimeout(_:operation:)` (races a `Duration` deadline; throws `TimeoutError`).
- `AppInfo`: version, build, bundleId, environment detection — API shaped so TestFlight detection can go async (`AppTransaction`) without breaking changes.
- `AppLanguage`: available/current languages from bundle, `AppleLanguages` override, `requiresRestart` flag. No bundle swizzling.

## 9. PalPersistence

- `KeychainService` (struct, `Sendable`) — **throwing** typed `KeychainError` (`encodingFailed`, `decodingFailed`, `unexpectedStatus(OSStatus)`); `read` returns nil ONLY for not-found; `kSecAttrAccessible` explicit (default `.afterFirstUnlock`, configurable).
- `UserDefaultsService` (`Sendable`, non-throwing — the one justified asymmetry) — plist-native types stored directly, JSON only for complex `Codable`.
- **Typed keys, uniform API:** `KeychainKey<Value>` / `DefaultsKey<Value>` (with optional default) — `get(_:)` / `set(_:for:)` / `delete(_:)`. Apps declare their own keys via static extensions; no app keys ship in the foundation.
- `MemoryCache` (actor): `CacheKey<Value>` with per-key TTL; `get/set/delete/clear`. **Passive TTL only** — store `(value, expirationDate)`, evaluate on `get`, delete-on-read if expired. NO sweepers, NO `Task.sleep` timers. **Memory-only is policy** — nothing persists across launches. Usage = repository-level cache-aside with `forceRefresh:` bypass; `clear()` on logout.
- Ships `PrivacyInfo.xcprivacy` (UserDefaults required-reason API declaration).

## 10. PalNetworking

- **Request model:** generic `Request<Response: Decodable & Sendable>` value type (method, path, query, headers, body, options). Per-app endpoints = one-line static factories returning `Request<DTO>`, defined in the app's Data layer.
- **Client:** `protocol NetworkClient: Sendable { func send<Response>(_ request: Request<Response>) async throws(NetworkError) -> Response }` + concrete `HTTPClient` (`Sendable`, immutable config; injectable `JSONDecoder` + `URLSessionConfiguration`). Single instance via DI scope — never a global `.shared`.
- **Error model:** `enum NetworkError: Error, Sendable` — `invalidRequest`, `transport(URLError)`, `unacceptableStatus(code: Int, data: Data)`, `decoding(DecodingError)`, `cancelled`. **Typed throws** on `send`. Server error body decoded on demand in the Data layer via `serverError(as:)`; client may hold one default backend-error decoder. Layering: client throws `NetworkError` → repository maps to domain error → presentation maps to `PresentableError`; `.cancelled` never surfaces.
- **Flow:** build `URLRequest` → interceptor chain → transport (`session.data(for:)`) → validate 2xx → decode (`EmptyResponse` marker for empty bodies; **`Data`/`String` responses bypass JSON decoding** — PDFs/files).
- **Interceptors (middleware onion):** chain currency is **`TransportRequest { urlRequest, options }`** (RequestOptions carries `requiresAuth`, retry overrides, custom flags). `protocol Interceptor: Sendable { func intercept(_ request: TransportRequest, next: Next) async throws(NetworkError) -> NetworkResponse }`. Interceptors are HTTP-level; typed decoding stays in `send` after the chain. Default order outer→inner: **Inspector (DebugKit) → Mock (DebugKit) → Logging → Retry → Auth → transport** (mocked exchanges appear in logs; inspector sees request start + timing).
- **LoggingInterceptor redaction (mandatory):** auth headers always redacted; bodies `.debug` only; `privacy: .private` for dynamics.
- **RetryInterceptor:** capped retries, exponential backoff, `error.isRetriable`, respects cancellation.
- **Auth refresh:** `actor TokenProvider` — single-flight via in-flight `Task` (check-and-set with no `await` between): N concurrent 401s → exactly 1 refresh. Protocols: `TokenStore` (foundation provides Keychain impl via PalAuth) · `TokenRefreshService` (**app-provided** — knows the refresh endpoint/DTOs). Logout signal: `AsyncStream<AuthEvent>` (`refreshed`, `loggedOut`) observed by the root coordinator. Refresh timing: reactive (401-driven) only. The refresh request sets `requiresAuth=false` (skips AuthInterceptor; no recursion).
- **Upload:** `HTTPBody.multipart(parts)` + file upload via URLSession upload task. Deferred: streaming download-to-disk.
- **Reachability (`v1.3.0`, additive):** `ReachabilityMonitor` (`@MainActor @Observable`, one per app at the composition root) over an internal `NWPathMonitor` seam (spy-tested). `NetworkStatus { isOnline, isExpensive, isConstrained }`; starts optimistically online (no offline flash at launch); `statusUpdates` follows the broadcast rule (independent subscription per access, replays current, dedupes). **For UX affordances only — never a request preflight gate** (attempt the request; failures surface through the normal error path).

## 11. PalAuth

- Glue product: `KeychainTokenStore` implementing `TokenStore` via `KeychainService` + `KeychainKey<AuthTokens>`. Keeps Networking and Persistence independent of each other.
- **Biometrics (`v1.3.0`, additive):** `BiometricAuthenticator` over an internal `LAContext` seam (spy-tested; fresh context per evaluation — the stale-context pitfall is Pal's problem, not the app's). `authenticate(reason:allowingPasscodeFallback:fallbackTitle:) throws(BiometricError) -> BiometricOutcome` — **cancellation and the fallback button are outcomes, not errors** (rule 12); real failures are typed (`unavailable`/`notEnrolled`/`lockedOut`/`failed`) for `.appAlert`. Reason/titles are app values; `NSFaceIDUsageDescription` is the app's plist duty.

## 12. PalPresentation

- `ViewState<Value: Sendable>`: `idle` · `loading(previous: Value?)` · `loaded(Value)` · `failed(PresentableError, previous: Value?)`. Previous value keeps content on screen during refresh/failed-refresh.
- `PresentableError`: `title`, `message`, `isRetryable`; domain errors map via one small protocol; localized default strings ship in-package (en + el).
- `Loader<Value: Sendable>` (`@MainActor @Observable`): the per-content runner a ViewModel **holds** — one per independently-loadable section. `state` is `private(set)` (only the loader mutates it). `load { }` — cancels the previous in-flight load (re-trigger dedupe), sets `.loading(previous:)`, maps errors to `PresentableError`, **swallows `CancellationError`**, `[weak self]`; `performLoad { } async` for `.task {}` (view-lifecycle cancellation); `refresh { } async` for `.refreshable {}` (reloads **in place** — no `.loading` transition, since the refresh control is the indicator); `cancel()`. The runner owns re-trigger cancellation; `.task` owns lifecycle cancellation. Multiple loaders per VM cover multi-section / partial-failure screens. *(Replaced the earlier `LoadableViewModelProtocol`, whose `{get set}` requirement couldn't keep `state` `private(set)` and allowed only one state per VM — see deviations log.)*
- Channel split: LOAD failures → `ViewState` · ACTION failures (screen keeps data) → `AppAlert` (DesignSystem).
- **`PagedLoader<Item, Cursor>` (`v1.1.0`, additive):** pagination machinery — accumulated items drive the same `ViewState`; `loadMore()` appends with its own footer state (`isLoadingMore` / `hasMore` / `loadMoreError` — a failed load-more keeps the list; retry = call `loadMore()` again). Operation injected at `init` (re-invoked with cursors, `nil` = first page) — a recorded asymmetry vs `Loader`. Documented trigger: the trailing footer row **outside the `ForEach`**, firing on `onAppear` (owner's pattern).

## 13. PalNavigation

- `protocol Routable: Hashable, Sendable` — route enums **carry payloads in cases** (`case detail(User)`). Trade-off recorded: entity payloads chosen over IDs (IDs are the state-restoration-friendly variant; restoration is a non-goal).
- `Router<Route: Routable>`: `@MainActor @Observable`; typed `[Route]` path (NOT `NavigationPath`); `push/pop(_:)/popToRoot/pop(to:)/replace(with:)`; **deep-link strategy API**: `navigate(to: [Route], strategy: .replace | .append)` (append protects in-progress user state when a push/deep link arrives).
- **Modals:** presentations modeled as **Identifiable items, never booleans** (`PresentedModal { id, route, style: .sheet/.fullScreen }`); RouterView binds `.sheet(item:)`/`.fullScreenCover(item:)`. Required test scenario: dismiss-then-immediately-present (auth-expired → login). Hybrid policy: screen-local UI modals (need Bindings into the presenting VM) stay view-level; **multi-screen flow modals** go through `router.present(_:)`/`dismiss()` with a nested `RouterView` (own stack; child→parent dismissal wired once).
- `RouterView<Route, Content>`: `NavigationStack(path:)` + `navigationDestination(for:)` + modal bindings + router in `.environment`. Zero `AnyView`, no view caching. Takes a plain destination closure — **no DI types in Navigation**.
- Per feature (app-side): one route enum + one `‹Feature›DestinationFactory` with an **exhaustive switch** (holds the resolver, constructor-injects VMs) + a `‹Feature›Coordinator` owning the Router and implementing the screens' `NavigationDelegate`s as one-liners.
- Ownership: the app shell holds the root coordinator (`@State`); the coordinator owns its `Router`; `RouterView` receives the router — never creates it.
- Deep links: `DeepLinkHandler` (URL → routes + strategy). Composition: one Router per tab; cross-package navigation via an app-level enum wrapping feature routes.

## 14. PalDesignSystem

- **Theme is OPT-IN and a deliberate MINIMAL BRIDGE** — it carries only the slots Pal's own components need; apps with a rich design system keep their full token layer and map a subset in. `@Environment(\.theme)` defaults to `Theme.system`; branding = one line `.theme(MyBrandTheme)`. Slots: colors (semantic, incl. `separator`), typography, spacing, radii, **shadows (elevation `level1`/`level2`, applied via `.shadow(_ token:)`)**. `ThemeTypography`: prefer `relativeTo:` for Dynamic Type; a fixed `.custom(_:size:)` is allowed when the brand needs pixel-fixed sizing.
- `.textStyle(_:)` reading theme tokens (apply LAST — returns `some View`). `TextStyleToken` carries font, optional color, and optional **`tracking` (letter spacing) + `lineSpacing`**; apps extend with their own tokens. Buttons: `ButtonStyle` conformance pattern; values app-defined. Raw SwiftUI styling always remains available.
- Components v1: `ErrorView` (full-screen `PresentableError` + Retry) · `SectionErrorView` (inline per-topic failure) · `EmptyStateView` · `LoadingView`. Accessibility labels on actions required. **No `StateView`** — screens keep the `ViewState` switch explicit (revisit only if dogfooding hurts).
- **Skeleton loading (`v1.1.0`, additive):** `.skeleton(when:)` (= redacted placeholder + shimmer + hit-testing off) and `.shimmering(active:)` (mask-based sweep — no color config, background-agnostic). The first-load affordance pairs with `loading(previous: nil)`; apps render real rows with **placeholder values** (masked — length only sizes the shapes). `LoadingView` stays for shapeless waits.
- **Scroll observation (`v1.1.0`, additive):** `.scrollObservationTarget()` (content marker) + `.onScrollOffsetChange` / `.onReachedBottom(threshold:)` (edge-triggered, re-arming) for plain `ScrollView` compositions — the iOS 17-floor equivalent of iOS 18's `onScrollGeometryChange`. **Deliberately neutral utilities:** the documented pagination trigger is the trailing row's `onAppear` in a `List`/lazy stack (owner's pattern), NOT `.onReachedBottom`.
- **DS additions (`v1.4.0`, additive — adoption feedback):** `surfaceElevated` color slot (floating chrome: sheets/alerts/toasts; **defaults to `surface`** so existing themes render identically — the alert/toast cards now draw from it) · `Color(hex:)` (UInt32 compile-checked + failable `#RRGGBB`/`#RRGGBBAA` string — every token layer was hand-rolling it) · `FlowLayout` (wrapping chip rows — the components bar of "wait for dogfooding demand" was met by two independent apps writing the same layout). *Evolution lesson, caught by the `api-stability` gate: inserting a defaulted parameter into an existing `init` is source-compatible but **removes the old signature** — the pre-`v1.4.0` `ThemeColors.init` is kept verbatim alongside the new one.*
- `.appAlert($alert)`: `AppAlert { kind: .info/.success/.warning/.error, title, message, primary, secondary? }`; app declares case alerts via static factories; `.error(PresentableError)` bridge built in. Custom-content overload `.appAlert($item) { CustomContent }` — foundation owns the chrome. **Known limitation:** a root-level overlay does not render above an active `.sheet` — apply per presentation context. **Toast shipped `v1.1.0`** (deliberately not v1): `AppToast { kind, title, message?, duration }` + `.appToast($toast)` — the non-blocking CONFIRMATION half of the ACTION channel (auto-dismiss, swipe/accessibility dismiss, replace-on-new-value, theme tokens, same per-presentation-context caveat).
- Generic SwiftUI utilities (`hideKeyboard`, `onFirstAppear`, …) live here, not in Core.
- String Catalogs in-package (`Bundle.module`), `defaultLocalization: "en"`, shipping **en + el**.

## 15. PalAnalytics & PalFeatureFlags

- `AnalyticsTracker` protocol: `track(_ event: AnalyticsEvent)`, `identify(userID:)`, `setUserProperty(_:for:)`, **`reset()`** (logout; pairs with `AuthEvent.loggedOut`). `AnalyticsEvent` = name + `[String: AnalyticsValue]` (`.string/.int/.double/.bool`, literal conformances). Apps define events as static factories. Impls shipped: `NoOp` (default registration), `Console` (via LoggerFactory), `Composite` (fan-out). SDK adapters live in the app at the composition root. ViewModels track; never Views; never repositories.
- `FeatureFlagsProvider` protocol: Bool-only `isEnabled(_ flag: FeatureFlag)`; `FeatureFlag { key, defaultValue }` declared via app extensions. Runtime model: fetch once at app start → seed `InMemoryFeatureFlagsProvider.update(_:)` → synchronous reads from memory; safe defaults when missing. Impls: `NoOp` (defaults only), `InMemory`/`Static`.

## 16. PalDebugKit (v1 = Logs + API switcher + Mocks)

- **Gating (final):** code ships unconditionally (SPM builds packages in release mode for any non-"Debug" app configuration; app flags don't propagate into packages). Activation is **runtime + default-OFF** (`PalDebugTools.enable(…)`). **The consumer app gates wiring behind ONE dedicated compilation flag `DEBUGKIT`** defined in whichever of ITS build configurations should carry tools (e.g. Debug + a Release-copy "Beta" archived for internal TestFlight). App Store config never defines it. Full opt-out = don't link the product.
- Presentation: `.onShake { PalDebugTools.shared.present() }` opens the menu in a dedicated **overlay `UIWindow` above alert level** — a contained `#if canImport(UIKit)` bridge (the only Pal package importing UIKit; the macOS host build excludes it). The debug UI is developer-facing and **not localized**. The base URL resolves per request via a nonisolated `EnvironmentResolver` (backing the client's `baseURLProvider`); in-flight cancellation on switch is app-owned (run from the broadcast event).
- **Logs:** `DebugInspectorInterceptor` (outermost) + `NetworkLogStore` actor — **capped ring buffer**, records request start (in-flight visible), timing, status/method/URL/headers/body; auth headers redacted in UI by default; observable store (UI subscribes — no singleton pokes).
- **API switcher:** `APIEnvironment` = app-defined payload (name + baseURL + whatever the app bundles: OAuth creds, extra URLs) — a switch swaps the whole config atomically. DebugKit lists/persists selection (typed `DefaultsKey`); the APP supplies the apply hook. Switch sequence: cancel in-flight first → swap → broadcast one "environment changed" event (`AsyncStream`) → each layer cleans itself (tokens, cache, navigation). No restart (baseURL provider closure reads current env per request). Custom/localhost entries supported.
- **Mocks:** `MockInterceptor` short-circuits the chain with stubbed `NetworkResponse`. Registry in memory, persisted as one JSON blob (Defaults helper), loaded once. Matching = method + path with query-normalization rules (never exact-URL equality). Capture→mock UX: toggle a logged call, **body auto-seeded from the captured response**, status editable; custom status honored WITH body (non-2xx surfaces as `unacceptableStatus`). Mocked exchanges appear in Logs.
- **Extensible from day one:** apps append custom tabs via the `@ViewBuilder` slot on `present(extraTabs:)` — no type-erased registry, honoring no-`AnyView`. Future modules (not v1): Flags viewer/overrides, Saved Logs export, language override, version spoofing.
- **Offline apps (ruled 2026-07-07):** DebugKit is deliberately a **network** debug kit — its value is the Logs/API/Mocks triad, so the PalNetworking coupling stays. Fully-local apps skip the product and roll a small app-side `#if DEBUG` menu (a shake shell with no tools isn't worth extracting). Revisit only if several apps bring concrete offline tools.

## 17. Localization

- Standard: **String Catalogs** + `String(localized:)` + Xcode generated symbols. No third-party tooling. Apps own their strings.
- Foundation packages with user-facing text (DesignSystem, Presentation, DebugKit) carry their own catalogs via `Bundle.module`, shipping **en + el**; components accept optional custom strings (override without forking).
- Formatting is locale-correct via `FormatStyle` (Core conveniences).
- Runtime switching: default = iOS per-app language Settings (automatic with ≥2 localizations). In-app switcher projects use `AppLanguage` (PalCore).

## 18. Recorded policies & trade-offs

- **Images:** default = native `AsyncImage` + documented `URLCache` sizing. Image-heavy apps adopt Nuke/Kingfisher **app-side**. No `PalImage` component in v1.
- **Pagination:** shipped `v1.1.0` as `PagedLoader` (§12) — the documented trigger is the trailing row's `onAppear`, not scroll geometry.
- **Route payloads:** entities (not IDs) — restoration-unfriendly, accepted deliberately.
- **Delegate growth:** watch during dogfooding; revisit if per-screen delegates bloat. (The delegation *pattern* is blessed — see §6.)
- **`StateView`:** deliberately not shipped; explicit switch preferred by owner.
- **DocC (post-1.0):** API reference is generated from the mandatory `///` docs + a curated `<Target>.docc` catalog per product, hosted on GitHub Pages. Built **plugin-free** via `xcodebuild docbuild` in CI — deliberately NOT `swift-docc-plugin`, which would put an external package in `Package.swift` and dent the zero-dependency guarantee. Cross-module symbols use plain code voice in doc comments (DocC links resolve only within a module). The markdown guides remain the narrative layer; DocC is the exhaustive symbol layer.

## 19. Workflows

- **Live-edit while building an app:** app depends on Pal via Git URL pinned; to edit, drag the local Pal folder into the app's workspace (local override wins) → edit live → commit, push, tag → remove override → bump pin.
- **`DEBUGKIT` recipe (per app):** add `DEBUGKIT` to `SWIFT_ACTIVE_COMPILATION_CONDITIONS` of each configuration that should carry tools; wrap `PalDebugTools.enable(…)` + Inspector/Mock interceptor wiring in `#if DEBUGKIT` at the composition root.
- **Release:** SemVer **tags** on `main`; consumers pin to tags (never a branch).
- **Source control (GitFlow):** `main` = live/consumer branch (tagged releases only) · `develop` = integration · `feature/{name}` off develop → back to develop · `hotfix/{name}` off main → merged to **both** main + develop (tag a patch). Contributors/agents push the `feature/*` branch and **request review before merging** (active from the Notifications feature onward).
- **Compatibility & evolution (open to extension, closed to modification):** the public API is a contract for the apps on Pal — evolve **additively** (new types, parameters with defaults, protocol requirements **only with default impls**), **deprecate don't delete** (`@available(*, deprecated, renamed:)`, remove only at a major), and treat a new public enum `case` as breaking. SemVer mapping: additive → minor · fix → patch · breaking → major (with deprecations first); since `1.0.0`, `from:` pinning is safe for consumers. There is no consumer-tracked `release/*` branch (tags are the channel); a `release/*` branch, if ever used, is a short-lived hardening branch, and a `1.x` maintenance line exists only to backport across a major. **The `api-stability` CI gate runs `swift package diagnose-api-breaking-changes`** against the latest release tag and fails on a break (active since `v1.0.0`).

## 20. Checklists

**Pre-app#1:** pagination pattern design · image strategy confirmation per app.
**Resolved at `v1.0.0`:** versioning/deprecation policy defined (§19) · public API freeze review done (clean) · `diagnose-api-breaking-changes` CI gate active. **Post-1.0 backlog (all additive):** DocC catalog · broad test coverage + `PalTestSupport` (Phase 11) · a networked second test app. *(LICENSE: MIT.)*

## 21. PalNotifications (push + local)

- **Scope v1:** typed permission (status/options) · local scheduling — `.immediate` (the fire-now, action-triggered client-side notification) / `.after(Duration)` / `.at(DateComponents, repeats:)` · APNs registration plumbing (token/failure as events; provider SDKs stay app-side, same seam philosophy as Analytics) · tap-response routing · foreground presentation policy · category/action registration · badge.
- **DAG edge → Core only**; imports the system `UserNotifications` framework (zero *external* dependencies holds). Callers never import UserNotifications for the basics — statuses/options/presentation are Pal's own `Sendable` types.
- **`NotificationService` is constructor-injected, no singleton.** Creating it claims the `UNUserNotificationCenterDelegate` seat — create it before launch finishes (a composition-root property), so cold-start taps are captured.
- **Streams follow the broadcast rule:** `responses` / `pushEvents` return an independent subscription per access (the DebugKit `environmentChanges` lesson, baked in from day one). Responses arriving before the first subscriber **buffer and replay** (cold-start tap → route); the **latest push event replays** to late subscribers (a token is state).
- **UIKit containment:** only `registerForRemoteNotifications()` touches UIKit (`#if canImport(UIKit)`, extension-unavailable); APNs callbacks arrive via the app's ~5-line `UIApplicationDelegateAdaptor` forwarding into `handleDeviceToken(_:)` / `handleRegistrationFailure(_:)`.
- **Testing seam:** an internal backend protocol wraps `UNUserNotificationCenter` (which needs an app host); the machinery is spy-tested in the package; the delegate-callback path (`UNNotification*` types are not constructible) is dogfooded in the Example.
- **`userInfo` crosses as `[String: String]`** (strings + stringified numbers) — deep-link keys and entity ids; complex payload handling stays app-side.
- **Guidance-only, deliberately outside v1:** Notification Service/Content Extensions (rich push — app targets, can't usefully ship from SPM); time-sensitive/critical interruption levels are additive later.

## 22. PalWeb (embedded web content, `v1.2.0`)

- **Scope: mechanisms for CONTENT pages** (terms, help, embedded pages) — `WebScreen` (a `WKWebView` representable, UIKit-gated like DebugKit's bridge) + `WebPageModel` (`@MainActor @Observable`: `ViewState<Void>` load state, live title/progress/history flags, `reload`/`goBack`/`goForward`). No `StateView` here either — the screen composes its own loading/error affordances around the web view, per the explicit-switch philosophy.
- **The seam is the navigation policy:** `WebNavigationPolicy = (WebNavigationRequest) -> WebNavigationDecision` (`allow` / `cancel` / `openExternally`) — the app ships the policy (which hosts stay in), Pal ships the machinery. Initial-request `headers` supported; cookie management deliberately NOT wrapped (additive later if dogfooding demands).
- **Named `WebScreen`, not `WebView`** — iOS 26's SwiftUI ships a native `WebView`; the name avoids the collision on newer floors.
- **OAuth stays OUT of embedded web views:** sign-in uses `ASWebAuthenticationSession` app-side (RFC 8252) — recorded guidance, not machinery. JS message bridge deferred (additive later).
- Cancelled navigations (`NSURLErrorCancelled`) never surface — the foundation's cancellation rule.

## 23. Implementation status & deviations log

Phase-by-phase status and the audit trail of approved deviations from this design are contributor-facing, not part of the design reference — they live in **[CONTRIBUTING](../CONTRIBUTING.md)**.

The standing rule: when implementation reality conflicts with this document, **stop, surface the conflict, and record the resolution** in CONTRIBUTING's deviations log. This document stays authoritative as the intended design.
