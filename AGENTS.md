# Pal — Agent Working Guide (AGENTS.md mirror of CLAUDE.md — keep in sync)

Pal is a reusable, zero-dependency iOS foundation: one Swift Package, multiple library products, consumed by apps via SPM. Swift 6 strict concurrency · iOS 17 floor · MVVM + Coordinators · Clean layering (Presentation / Domain / Data).

**Canon:** [Documentation/DECISIONS.md](Documentation/DECISIONS.md) is the single source of truth for every locked decision. [Documentation/ARCHITECTURE.md](Documentation/ARCHITECTURE.md) explains structure and patterns. If anything here seems to conflict, DECISIONS.md wins. Do not relitigate locked decisions — propose changes to the owner instead.

## The law of the codebase

**The foundation ships mechanisms; apps ship values.** Concrete endpoints, user-facing strings, brand tokens, storage keys, analytics events, environments, and validation rules NEVER live in Pal packages — apps supply them via typed keys, static factory extensions, and protocol conformances.

## Build & verify

```bash
swift build        # all package targets
swift test         # smoke + targeted tests
# Example app: open Example/PalExample.xcodeproj (or xcodebuild -project ... -scheme PalExample)
```

Every change must leave `swift build` + `swift test` green and the Example app compiling. CI enforces this on push/PR.

## Package dependency DAG (enforced — never add edges)

`PalCore→∅` · `PalPersistence→Core` · `PalNetworking→Core` · `PalAuth→Core,Networking,Persistence` · `PalPresentation→Core` · `PalNavigation→∅` · `PalDesignSystem→Core,Presentation` · `PalAnalytics→Core` · `PalFeatureFlags→Core` · `PalDebugKit→Core,Networking,Persistence` (not DesignSystem) · `PalNotifications→Core`.

Every target declares ALL modules it directly imports (no transitive reliance). No SwiftUI in PalCore. Zero external dependencies in the package — Swinject exists only app-side (Example).

## Naming conventions (SCOPED — binding)

- **App-layer seams** (in apps and the Example app) use explicit suffixes:
  - Use cases: `‹Verb›‹Entity›UseCaseProtocol` → impl `‹Verb›‹Entity›UseCase`, exactly ONE method `execute(...)`. No marker base protocol.
  - Repositories: `‹Entity›RepoProtocol` → impl `‹Entity›Repository` (deliberate asymmetry). Entity-based by default; capability-based when the seam is a capability.
  - Navigation delegates: `‹Screen›NavigationDelegate` with intent-named methods (`showUserDetail(_:)`).
- **Foundation public API uses standard Swift naming** (Swift API Design Guidelines): `NetworkClient`, `TokenStore`, `Interceptor`, `Routable`, `KeychainService`…
  **GUARD: never rename foundation protocols to add `…Protocol` suffixes.** `TokenStore` must NOT become `TokenStoreProtocol`. The suffix convention is app-layer only.
- Storage/cache verbs are uniform: `get` / `set` / `delete`.

## Clean-code rules (binding)

1. **No user-facing string literals in Views/ViewModels** — String Catalog keys via `String(localized:)`/generated symbols only.
2. **No implementation comments** — self-documenting naming; sole exception: a genuinely non-obvious constraint/workaround, explaining WHY never WHAT. No commented-out code. `// MARK:` dividers permitted. **`///` documentation comments are REQUIRED on every public symbol.**
3. Follow the naming conventions above exactly.
4. **No force-unwraps / `try!` / `as!`** — sole exception: DI resolution at the app's composition root (fail-fast by design).
5. **No `print()`** — `LoggerFactory` only (opt-in). **Never log secrets:** auth headers always redacted; bodies at `.debug` only; `privacy: .private` for dynamic values.
6. **No `AnyView`** or type-erasure workarounds.
7. No magic numbers in UI — theme tokens for spacing/radii where DesignSystem is used.
8. **One primary type per file**, named after it — a protocol may be co-located with its single conforming implementation (e.g. `FetchUsersUseCaseProtocol` + `FetchUsersUseCase` in `FetchUsersUseCase.swift`). Extensions as `Type+Feature.swift`.
9. Explicit access control; smallest public surface.
10. Layer rules: Views never touch clients/repos; ViewModels import Domain only; DTO↔entity mapping lives in Data; dependency arrows point inward.
11. Swift 6 hygiene: no `@unchecked Sendable` without written justification; `@MainActor` ViewModels; actors for shared mutable state.
12. Errors are never silently swallowed; mapped at boundaries (`NetworkError` → domain error → `PresentableError`); cancellation never surfaces to users.
13. **Reference types are `final` by default** — every class is `final` unless explicitly designed for subclassing (enables static dispatch, signals intent). Structs, enums, and actors need no annotation.

## The canonical per-screen pattern

Every screen: `@MainActor @Observable` ViewModel holding one or more `Loader<Value>` (each drives a `ViewState`: `idle / loading(previous:) / loaded / failed(error, previous:)`); call `loader.load { }` (auto-cancels the previous in-flight load, swallows cancellation, maps to `PresentableError`); the View switches on `viewModel.‹loader›.state`. Navigation goes through the screen's `NavigationDelegate`, implemented by the feature coordinator as one-liners over the typed `Router`. Dependencies arrive via `init` (constructor injection from the app-side factory). Load failures → `ViewState`; action failures → `.appAlert`.

## Patterns & evolution (binding)

- **Delegation (child → owner):** when a child reports back to its owner (navigation, flow completion), use a `‹Context›Delegate` — `@MainActor`, `AnyObject`, held **weak**, intent-named. A closure for a one-shot callback; an `AsyncStream` for broadcast events (`AuthEvent`). See [DECISIONS §6](Documentation/DECISIONS.md).
- **Compatibility — open to extension, closed to modification:** the public API is a contract for the apps on Pal. Additive only; new protocol requirements ship with default impls; **deprecate (`@available`), never delete** pre-major; consumers track SemVer **tags**, never branches.
- **Source control:** GitFlow (`main` live/tagged · `develop` integration · `feature/*` off develop · `hotfix/*` off main → both). **Push the task branch and ask before merging.** Full policy in [CONTRIBUTING](CONTRIBUTING.md).

## Documentation map

- [Getting Started](Documentation/GettingStarted.md) — install → composition root → first feature.
- [Architecture](Documentation/ARCHITECTURE.md) — layers, the DAG, patterns, adoption notes.
- [Per-product guides](Documentation/Products/) — the API and usage of each product.
- [DECISIONS](Documentation/DECISIONS.md) — the design and its rationale (a living document, open to discussion).
- [CONTRIBUTING](CONTRIBUTING.md) — build/verify, **implementation status & phase log**, and the deviations log.

**Status lives in CONTRIBUTING** (single source — do not restate it here, so it can't go stale). At a glance: all 11 products are built. **When you change an API, a decision, or a product's behavior, update the affected docs in the same change.**
