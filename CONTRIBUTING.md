# Contributing to Pal

> For people — and agents — working **on** Pal. If you are *adopting* Pal in an app, start with [Getting Started](Documentation/GettingStarted.md) instead.

## Build & verify

```bash
swift build        # all package targets
swift test         # smoke + targeted tests
# Example app: open Example/PalExample.xcodeproj (or xcodebuild -project … -scheme PalExample)
```

Every change must leave `swift build` + `swift test` green **and** the Example app compiling. CI enforces this on push/PR on **both toolchain edges** — `macos-15` (Xcode 16 / Swift 6.1, the consumer floor) and `macos-26` (latest) — plus the `api-stability` gate; the two-edge matrix exists because newer SDKs concurrency-annotate system frameworks, so one edge can pass where the other breaks (the `v1.3.1` lesson, in the deviations log). The macOS 14 platform floor exists only so the host can build/test; products target iOS — UIKit-only surfaces are gated with `#if canImport(UIKit)`.

**API reference docs are generated, not hand-written:** the `Docs` workflow builds DocC for all 12 products on every release tag (plugin-free `xcodebuild docbuild` — the package manifest stays zero-dependency) and publishes to [GitHub Pages](https://mesrine23.github.io/pal-mvvm-foundation/). Each product has a curated `Sources/<Target>/<Target>.docc` catalog: **when you add a public symbol, add it to the catalog's Topics** (an uncurated symbol still appears, just unorganized — visible decay, fix it in the same change).

## The rules are binding

The naming conventions and the 12 clean-code rules in [DECISIONS.md §4–5](Documentation/DECISIONS.md) (mirrored in [CLAUDE.md](CLAUDE.md) / [AGENTS.md](AGENTS.md)) are binding for humans and agents alike. Highlights worth re-reading before a PR: `///` on every public symbol · no force-unwraps/`AnyView`/`print` · scoped naming (foundation API uses standard Swift naming; the `…Protocol` suffix is app-layer only) · errors mapped at boundaries.

**Documentation follows every change.** When you add or change a public API, a decision, or a product's behavior, update the affected docs in the same change: the relevant [product guide](Documentation/Products/), [DECISIONS.md](Documentation/DECISIONS.md), [ARCHITECTURE.md](Documentation/ARCHITECTURE.md), and the status below.

## Governance: decisions are a living document

[DECISIONS.md](Documentation/DECISIONS.md) records the intended design. Pal is built to be scalable and maintainable, so it is **open to discussion** — propose changes rather than drifting silently. When implementation reality conflicts with the design, **stop, surface the conflict, and record the resolution in the deviations log below.** The design text stays authoritative; this log is the audit trail of approved exceptions.

## Source control (GitFlow)

- **`main`** — the live branch consumers track. Only **tagged releases** land here; never commit features directly to it.
- **`develop`** — the integration branch where finished features accumulate between releases.
- **`feature/{name}`** — branch off `develop`; merge back into `develop` when done.
- **`hotfix/{name}`** — branch off `main` for an urgent fix; merge into **both** `main` (tag a patch, e.g. `v1.0.1`) **and** `develop` (so the next release doesn't revert it).
- A release is `develop → main` plus a SemVer **tag**, a **[CHANGELOG.md](CHANGELOG.md) entry**, and a GitHub Release. **Consumers pin to tags, never to a branch.**
- **Merge discipline:** push the `feature/*` (or `hotfix/*`) branch and **request review before merging** — don't self-merge into `develop`/`main` without a cross-check. *(Active from the Notifications feature onward.)*

## Compatibility & evolution

Pal is consumed by multiple apps, so the public API is a **contract** — *open to extension, closed to modification.*

- **Evolve additively.** New types, new parameters with default values, and new protocol requirements **only with default implementations** (a bare new requirement breaks every conformer in every app).
- **Deprecate, don't delete.** Keep the old symbol and forward it; remove only at a major bump, a release after the deprecation:
  ```swift
  @available(*, deprecated, renamed: "send(_:)")
  public func execute<R>(_ request: Request<R>) async throws(NetworkError) -> R { try await send(request) }
  ```
- **Mind enums.** Adding a `case` to a public enum is source-breaking (consumer `switch`es are exhaustive) — reserve case additions for a major.
- **SemVer mapping:** additive → minor · fix → patch · breaking → major (with deprecations first). Since `1.0.0`, `from:` pinning is safe for consumers — minors and patches never break.
- **Consumers track tags, never branches.** No `release/x.y.z` branch is meant to be followed; a `release/*` branch (if ever used) is a short-lived hardening branch deleted after tagging, and a long-lived `1.x` maintenance line exists only to backport fixes across a major.
- **Active since `1.0.0`:** CI's `api-stability` job runs `swift package diagnose-api-breaking-changes` against the **latest release tag** and fails on a break. A deliberate break (major release) is the one case where the job is expected to fail — ship it with the new major tag, and the gate re-baselines automatically.

## Implementation status

Each phase ends GREEN: `swift build` + `swift test` pass and the Example app compiles.

| Phase | Product | Status | Tag |
|---|---|---|---|
| 0 | Scaffold (spec, Package.swift + DAG, agent docs, CI) | ✅ | `v0.1.0` |
| 1 | PalCore — LoggerFactory · extensions · Debouncer/withTimeout · AppInfo · AppLanguage | ✅ | `v0.2.0` |
| 2 | PalPersistence — Keychain · UserDefaults · typed keys · MemoryCache · privacy manifest | ✅ | `v0.3.0` |
| 3 | PalNetworking — Request/TransportRequest · NetworkError · HTTPClient · onion + Logging/Retry/Auth · TokenProvider · multipart/upload | ✅ | `v0.4.0` |
| 4 | PalAuth — KeychainTokenStore | ✅ | `v0.5.0` |
| 5 | PalPresentation — ViewState · PresentableError · `Loader<Value>` (runner reworked in `v0.10.0`) | ✅ | `v0.6.0` |
| 6 | PalNavigation — Routable · Router (strategy API, Identifiable modals) · RouterView · DeepLinkHandler | ✅ | `v0.7.0` |
| 7 | PalDesignSystem — Theme (colors/typography/spacing/radii/shadows) + textStyle · state views · appAlert (extended in `v0.10.0`) | ✅ | `v0.8.0` |
| 8 | PalAnalytics + PalFeatureFlags — protocols + NoOp/Console/Composite/InMemory | ✅ | `v0.9.0` |
| 9 | PalDebugKit — NetworkLogStore + Inspector/Mock interceptors · overlay shake menu · Logs/API/Mocks · `baseURLProvider` env switching | ✅ | `v0.13.0` |
| 10 | Example app — composition root (manual DI) · canonical Users slice (list/detail) + Settings · dogfoods every product | ✅ | `v0.12.0` |
| 11 (deferred) | Broad tests + PalTestSupport · reachability · streaming download-to-disk | — | — |
| 12 | PalNotifications — NotificationService · permission · local scheduling (immediate/delayed/calendar) · APNs token plumbing · response routing · foreground policy · categories | ✅ | `v1.0.0` |

Tests today: smoke + MemoryCache + TokenProvider single-flight + interceptor-chain + Router + Loader (incl. `refresh`) + DebugKit (log ring buffer, inspector capture, mock interceptor 2xx/non-2xx + global-off un-mocks-all, env store broadcast/re-select/removal-fallback, resolver fallback) + Notifications (content/trigger/options/status/category mapping via a spy backend, response broadcast + cold-start buffering, push events + latest-replay) + DesignSystem snippet compile-guards (scroll observation, shimmer/skeleton) + PagedLoader (append/dedupe/refresh-reset/footer-error/cancellation) + PalWeb (page-model state machine, cancellation swallow, navigation values) + ReachabilityMonitor (tracking, flags, replay-current, broadcast/dedupe) + BiometricAuthenticator (availability, parameter passthrough, cancellation-as-outcome, typed error mapping). The Example app builds for the iOS Simulator (0 warnings), dogfooding **all 12 products** (DebugKit wired behind `DEBUGKIT`).

> **`v1.0.0` shipped** (2026-07-02): all 11 products, dogfooded by two apps (the networked Example + a local-only SwiftData app), API review clean, additive-only evolution tool-verified from `v0.13.0`. The public API is now under the compatibility policy above, enforced by the `api-stability` CI gate.

### Post-1.0 additions (approved roadmap — all additive)

| Addition | Product | Status | Ships in |
|---|---|---|---|
| Shimmer + skeleton (`.shimmering` / `.skeleton`) | PalDesignSystem | ✅ | `v1.1.0` |
| Scroll observation (`.scrollObservationTarget` + `.onScrollOffsetChange` / `.onReachedBottom`) | PalDesignSystem | ✅ | `v1.1.0` |
| `PagedLoader` + pagination pattern docs (owner's last-row `onAppear` trigger is the documented primary) | PalPresentation | ✅ | `v1.1.0` |
| Toast (non-blocking ACTION channel) | PalDesignSystem | ✅ | `v1.1.0` |
| `PalWeb` — WebScreen + navigation policy seam + external-link opener | new product | ✅ | `v1.2.0` |
| Reachability (`NWPathMonitor` seam) | PalNetworking | ✅ | `v1.3.0` |
| `BiometricAuthenticator` | PalAuth | ✅ | `v1.3.0` |
| BarRoster feedback: `surfaceElevated` slot · `Color(hex:)` · `FlowLayout` + docs batch (editor pattern, optional-content idiom, reload-on-return, local-app recipe) | PalDesignSystem/docs | ✅ | `v1.4.0` |

Parked (owner hold / no verdict): keyboard utilities beyond `hideKeyboard()` · PalTestSupport + broad tests (Phase 11) · DocC · a networked second test app. Declined for now: DebugKit round 2 (flags tab, log export, per-client custom envs).

> **`v1.1.0` shipped** (2026-07-03): the list-screen bundle — skeleton/shimmer, scroll observation, `PagedLoader` + the canonical pagination pattern (dogfooded by the Example's Posts tab), and toast. Additive-only, verified against `v1.0.0` with `diagnose-api-breaking-changes`.
>
> **`v1.2.0` shipped** (2026-07-03): `PalWeb` — the 12th product (`WebScreen` + `WebPageModel` + navigation policy + `ExternalLinkOpener`), dogfooded by the Example's About screen. Additive-only, tool-verified against `v1.1.0`.
>
> **`v1.3.0` shipped** (2026-07-03): resilience & trust — `ReachabilityMonitor` (PalNetworking) and `BiometricAuthenticator` (PalAuth). Additive-only, tool-verified against `v1.2.0`. This completes the approved post-1.0 roadmap; remaining items are parked (see above).
>
> **`v1.3.1` shipped** (2026-07-03): toolchain-portability hotfix — `PalNotifications` now builds on Xcode 16 / Swift 6.1 as well as Xcode 26 (see the deviations log). No API change.
>
> **`v1.4.0` shipped** (2026-07-07): the BarRoster feedback batch — `surfaceElevated` theme slot (adopted by alert/toast chrome, defaults to `surface`), `Color(hex:)`, `FlowLayout`, plus the ergonomics docs (editor-screen pattern, optional-content idiom, reload-on-return, fully-local recipe, `PresentableError(from:)` surfaced). Additive-only, tool-verified against `v1.3.1`.

## Deviations log

The audit trail of approved exceptions where implementation reality met the design.

- **Docs/CI tooling merged to `main` WITHOUT a release tag (2026-07-04).** GitFlow says `main` carries tagged releases only, but the `Docs` workflow must live on `main` for tag pushes to trigger it, for `workflow_dispatch`, and for Pages deploys — so the DocC/CI-matrix infra merged untagged. No package source changed; consumers pin tags and are unaffected. DocC itself is built **plugin-free** (`xcodebuild docbuild` in CI) so `Package.swift` keeps its zero-dependency guarantee — see DECISIONS §18. **Repo-settings state (invisible in the repo):** the `github-pages` environment's deployment policy must allow **tags matching `v*`** in addition to `main` — GitHub only allows `main` by default, which silently fails the `deploy` job on tag-triggered runs (hit at `v1.4.0`; fixed via `gh api …/environments/github-pages/deployment-branch-policies -f name='v*' -f type=tag`).

- **Phase 1 — macOS 14 platform floor added to `Package.swift`.** `swift build`/`swift test`/CI compile for the host Mac; without a declared floor SPM assumes macOS 10.13 and modern APIs (os.Logger, Duration, Observation) fail. Products remain iOS-targeted; macOS is build-infrastructure only; UIKit-only surfaces get `#if canImport(UIKit)`.
- **Phase 1 — `AppInfo` distribution detection (TestFlight/App Store) deferred.** The modern API (`AppTransaction`) requires StoreKit, breaching Core's Foundation-only rule; the receipt heuristic is deprecated. Ship nothing rather than either cost; `distribution() async` is purely additive later, where the first consumer lives.
- **Phase 2 — privacy manifest added to PalCore as well** (design mentioned only PalPersistence): `AppLanguage` writes `AppleLanguages` via UserDefaults — a required-reason API (CA92.1) — so PalCore must also declare it.
- **Polish pass (post-POC) — status docs were stale.** `CLAUDE.md` "Current status" and the phase list still read "Phase 0 / empty stubs" at `v0.9.0` — caught by the TheLoot adoption agent. Fixed. **Process rule: update status docs every phase.**
- **Polish pass — runner redesigned `LoadableViewModelProtocol` → `Loader<Value>`.** The protocol+extension couldn't keep `state` `private(set)` against a `{get set}` requirement (its canonical example didn't compile) and supported only one loadable state per VM. Replaced by an owned `Loader<Value>` object: encapsulated state, no `loadTask` boilerplate, multiple sections per screen. **Breaking API change (pre-1.0, acceptable).** A compile-tested reference example (`PalPresentationTests`) now guards the canonical pattern from silent rot.
- **Polish pass — PalDesignSystem `Theme` extended + reframed.** Added a shadow/elevation scale (`ThemeShadows` + `.shadow(_ token:)`), a `separator` color, and `tracking`/`lineSpacing` on `TextStyleToken`; softened the custom-font "MUST `relativeTo:`" to allow fixed sizes; documented `Theme` as a deliberate minimal bridge.
- **Documentation pass — consumer-facing docs added; history relocated here.** Added per-product guides (`Documentation/Products/`), a Getting Started guide, and this file; reframed `DECISIONS.md` as a design reference (history moved out) and softened its framing to "open to discussion". Implementation history (phase status + this deviations log) now lives here, separated from the consumer docs.
- **Phase 9 — PalDebugKit is the one UIKit-using package.** Shake detection and above-everything overlay aren't expressible in pure SwiftUI, so DebugKit contains UIKit behind `#if canImport(UIKit)` (`UIViewControllerRepresentable` for `.onShake`, `UIWindow` for the overlay) — the only Pal package importing UIKit; the macOS host build excludes it. `HTTPClient.baseURLProvider` was reintroduced for per-request env switching. Env routing splits into a nonisolated `EnvironmentResolver` (synchronous reads backing the `@Sendable` `baseURLProvider`) + a `@MainActor` `EnvironmentStore` (UI + persistence). An artificial-latency knob was prototyped for mocks (stored in milliseconds — `Duration` isn't `Codable`) and later cut in the owner's pre-publish review; the shipped editor is mocked/status/body only. The debug menu is **deliberately not localized** (developer-facing, not user-facing) — an exception to the en+el rule. DebugModule registration is realized as built-in tabs + a `@ViewBuilder` slot (no type-erased registry, honoring no-`AnyView`).
- **Phase 9 polish (pre-publish, `v0.13.0`).** Pull-to-refresh: added `Loader.refresh(_:)` (in-place reload — no `.loading`, since the refresh control is the indicator) plus the keep-the-scrollable-mounted pattern (empty/error as overlays), after the Example surfaced a "change the refresh control while it is not idle" conflict on a refresh-to-empty. DebugKit UI refined per owner review — Logs: always-visible search, request body + query params in detail, larger body cap; Mocks: a searchable list of every executed call (reusing the Logs row) with a focused 3-control editor (mocked / status / body), mocked-first ordering, and global-off un-mocks everything.
- **Phase 10 built ahead of Phase 9 (owner preference).** A runnable Example showcase (Users canonical slice + Settings) dogfooding the 9 shipped products via manual DI against a public API; PalDebugKit is excluded until Phase 9. Each Pal product was linked into the app target in `project.pbxproj` (sources auto-include via Xcode's synchronized file groups). Because the app target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, the Domain/Data value types are marked `nonisolated` so DTOs decode and entities construct off the main actor — exactly the adoption guidance in [ARCHITECTURE.md](Documentation/ARCHITECTURE.md).
- **`v1.0.0` released with two DECISIONS §20 pre-1.0 checklist items moved to the post-1.0 backlog (owner decision).** Broad test coverage + `PalTestSupport` (Phase 11) and the DocC catalog are both purely **additive** — deferring them doesn't touch the API contract 1.0.0 freezes. The rest of the checklist was met: the versioning/deprecation policy is defined and CI-enforced (`api-stability` gate), the API review pass was clean (naming, `final`, justified `@unchecked Sendable`, no dead/deprecated surface), and `diagnose-api-breaking-changes` verified `v0.13.0 → v1.0.0` as strictly additive. Remaining backlog: DocC · PalTestSupport + broad tests · a networked second test app.
- **BarRoster adoption feedback (`v1.4.0`).** A third external app (fully-offline, 8 screens, ~6 000 lines, CSP solver) was built **docs-first with zero foundation source files opened** — the strongest validation of the documentation standard yet, on the opposite app shape from the Example. Every punch-list item was ergonomic, none structural. Actions: one item was a *false* gap (`PresentableError(from:)` already existed publicly — the guide never mentioned it; now it does), a docs batch (editor-screen draft pattern, optional-content-as-domain-case idiom, reload-on-return idiom, fully-local recipe, `EmptyStateView` signature, `.textStyle` import note, Xcode-26 template-defaults note, `@ModelActor` granularity, async-quarantine consequence, editable-route-payload seed pattern), and three additive DS pieces (`surfaceElevated`, `Color(hex:)`, `FlowLayout` — requested independently by two apps). Both deferred items were **ruled on 2026-07-07**: DebugKit stays network-coupled by design (offline apps roll an app-side `#if DEBUG` menu — DECISIONS §16), and `AppAlert`/`AppToast` stay in PalDesignSystem with the ViewModel import now the blessed shape (layer rule 10) — a typealias move would trip both the `api-stability` gate (struct→typealias reads as a removal) and `MemberImportVisibility` apps (Xcode 26's default), so the "clean" move was the riskier one.
- **Docs pass — MyRecipes adoption feedback (no source change).** A second test app (local-only SwiftData CRUD, Swinject DI) built fully on Pal **section by section with zero foundation changes** — strong evidence the API is followable from docs alone, and a live proof of the additive-evolution policy (every finding was a docs gap, not a wrong mechanism). Actions: (1) fixed two non-compiling shipped snippets — GettingStarted's `.task { performLoad { refresh() } }` (the closure must return `Value`, not `Void`) and PalNavigation/GettingStarted's `RouterView` (omitted the required `root:` route case); (2) **extended the compile-tested-snippet discipline** to the `RouterView` usage (`PalNavigationTests`) and the `performLoad`-based VM `load()` (`PalPresentationTests`) so consumer-doc snippets can't silently drift from the API; (3) added adoption guidance with **no code/deps in Pal** — SwiftData-behind-repositories (`@ModelActor` + domain-struct mapping + re-fetch-after-write), app-layer modularization as local SPM packages, and a `nonisolated`-tokens note for `MainActor`-default isolation; (4) recorded the **source-control (GitFlow)** + **compatibility/evolution** policy (above). The coverage caveat stands: a local-only app leaves PalNetworking/PalAuth/most of DebugKit/MemoryCache unexercised — a networked second test app would validate the other half (the Example app already covers the networked path).
- **`v1.3.1` — toolchain-portability hotfix (Xcode 16 ↔ 26).** CI (`macos-15` = **Xcode 16.4 / Swift 6.1 / macOS 15 SDK**) failed to build `SystemNotificationCenter` from `v1.0.0` onward: `await center.notificationSettings()` / `pendingNotificationRequests()` return non-`Sendable` `UNNotificationSettings` / `[UNNotificationRequest]` across the `@MainActor` boundary. **Local dev on Xcode 26 (macOS 26 SDK) hid it** — the newer SDK concurrency-annotates `UserNotifications`, so the results stay on-actor. Fix: `@preconcurrency import UserNotifications` (idiomatic for an un-audited framework; a no-op on newer SDKs). **Process lesson: `swift build`/`swift test` on the latest Xcode can mask strict-concurrency gaps in system frameworks that older-but-widely-used toolchains still flag — the `macos-15` CI job is the safety net for consumers on that toolchain; watch it.** Also hardened the `api-stability` job: it now hard-fails only on a *detected* API breakage, and warns-and-skips when the baseline tag no longer builds on the CI toolchain (every tag ≤ `v1.3.0` carries this bug, so an API diff against them can't compile the baseline).
