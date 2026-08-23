# Pal for adopters — the agent brief

<!-- CANONICAL SOURCE for adopter-facing agent context. The pal-adopter plugin bundles this
     file verbatim and site/llms.txt links it; neither restates it. Version stamp below is
     checked at release time by .claude/skills/release.
     Every link here is ABSOLUTE on purpose: this file is read from three places — this repo, an
     adopter's own AGENTS.md, and the plugin's reference/ — and only absolute links work in all three.
     Do not "tidy" them into relative paths. -->

> **Written for Pal `v1.5.2`.** Check yours: the tag in your `Package.resolved`, or `AppInfo` at runtime.

**Copy the body of this file into your app's `AGENTS.md` under a `## Pal` heading** (or install the [`pal-adopter` plugin](https://github.com/Mesrine23/pal-mvvm-foundation/tree/main/plugins/pal-adopter), which ships it for you). It is deliberately short — it has to fit inside *your* app's instruction budget alongside your own rules.

---

## What Pal is, and what stays yours

Pal is a zero-dependency Swift Package of twelve library products — Swift 6 strict concurrency, iOS 17+, MVVM + Coordinators, Clean layering. It ships **mechanisms**. Your app ships **values**.

**This is the rule agents break most often.** Base URLs, user-facing strings, brand colors, storage keys, analytics event names, environments, validation rules — these never belong in Pal, and you never need to change Pal to supply them. You provide them through typed keys, static factory extensions on Pal types, and conformances to Pal protocols. If a task feels like "Pal is missing X", check first whether X is a value; it usually is.

Pal also cannot ship your `@main`, root scene, `Info.plist`, entitlements, or composition root. Those are yours, written once.

## Which product for which need

| You need | Use | Guide |
|---|---|---|
| Logging, `AppInfo`, `AppLanguage`, async utilities | `PalCore` | [→](https://github.com/Mesrine23/pal-mvvm-foundation/blob/main/Documentation/Products/PalCore.md) |
| Keychain, UserDefaults with typed keys, TTL cache | `PalPersistence` | [→](https://github.com/Mesrine23/pal-mvvm-foundation/blob/main/Documentation/Products/PalPersistence.md) |
| Typed HTTP, interceptors, single-flight auth refresh, reachability | `PalNetworking` | [→](https://github.com/Mesrine23/pal-mvvm-foundation/blob/main/Documentation/Products/PalNetworking.md) |
| Keychain-backed token store, Face ID / Touch ID | `PalAuth` | [→](https://github.com/Mesrine23/pal-mvvm-foundation/blob/main/Documentation/Products/PalAuth.md) |
| Screen state: `ViewState`, `Loader`, `PagedLoader`, `PresentableError` | `PalPresentation` | [→](https://github.com/Mesrine23/pal-mvvm-foundation/blob/main/Documentation/Products/PalPresentation.md) |
| Typed routes, `Router`, deep links, flow modals | `PalNavigation` | [→](https://github.com/Mesrine23/pal-mvvm-foundation/blob/main/Documentation/Products/PalNavigation.md) |
| Theming, text styles, state views, alerts, toasts, skeletons | `PalDesignSystem` | [→](https://github.com/Mesrine23/pal-mvvm-foundation/blob/main/Documentation/Products/PalDesignSystem.md) |
| Analytics seam / feature-flag seam | `PalAnalytics` · `PalFeatureFlags` | [→](https://github.com/Mesrine23/pal-mvvm-foundation/blob/main/Documentation/Products/PalAnalytics.md) |
| Shake-to-debug: network logs, env switcher, mocks | `PalDebugKit` | [→](https://github.com/Mesrine23/pal-mvvm-foundation/blob/main/Documentation/Products/PalDebugKit.md) |
| Push + local notifications | `PalNotifications` | [→](https://github.com/Mesrine23/pal-mvvm-foundation/blob/main/Documentation/Products/PalNotifications.md) |
| Embedded web pages, external-link opening | `PalWeb` | [→](https://github.com/Mesrine23/pal-mvvm-foundation/blob/main/Documentation/Products/PalWeb.md) |

Import only what you use — each product declares its own dependencies. A fully-offline app typically takes five: Core, Presentation, Navigation, DesignSystem, Persistence.

## The shape of a screen

Every screen is the same slice — **View → ViewModel → UseCase → Repository → client**, dependencies pointing inward:

- A `@MainActor @Observable` ViewModel owns one or more `Loader<Value>`.
- Each `Loader` drives a `ViewState`: `idle / loading(previous:) / loaded / failed(error, previous:)`. The View switches on it — no `isLoading` booleans, no manual error flags.
- `loader.load { }` cancels the previous in-flight load, swallows cancellation, and maps failures to `PresentableError`. Use `performLoad` when you need to await it.
- Navigation leaves the ViewModel through a `‹Screen›NavigationDelegate`, implemented by the feature coordinator over a typed `Router`.
- Dependencies arrive via `init`, from a factory method on your composition root.

**Three channels, don't mix them:** load failures go to `ViewState`; action failures go to `.appAlert`; action confirmations go to `.appToast`.

One screen firing several calls that finish together needs **one** `Loader` over a composite value, not one per call. Give a section its own `Loader` only when it reloads independently. The worked examples are in [GettingStarted](https://github.com/Mesrine23/pal-mvvm-foundation/blob/main/Documentation/GettingStarted.md#4-your-first-feature-the-canonical-vertical-slice).

## Naming in your app

Pal's own public API uses standard Swift naming (`NetworkClient`, `TokenStore`, `Router`) — never add a `…Protocol` suffix to it. Your app-layer seams use explicit suffixes:

- Use cases: `‹Verb›‹Entity›UseCaseProtocol` → `‹Verb›‹Entity›UseCase`, exactly one method `execute(...)`.
- Repositories: `‹Entity›RepoProtocol` → `‹Entity›Repository` (the asymmetry is deliberate).
- Navigation delegates: `‹Screen›NavigationDelegate`, methods named for intent (`showUserDetail(_:)`).

Xcode file templates for all three are in [`Templates/Xcode/`](https://github.com/Mesrine23/pal-mvvm-foundation/tree/main/Templates/Xcode).

## Gotchas that cost the most time

- **Main-actor-default isolation.** If your app target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (Xcode 26's default for new projects), mark Domain and Data value types `nonisolated` so DTOs decode and entities construct off the main actor.
- **Never edit Pal in DerivedData.** A pinned dependency is checked out read-only; edits there are untracked and vanish on the next resolve. To change the foundation, edit its repo — the local-override loop is in [GettingStarted](https://github.com/Mesrine23/pal-mvvm-foundation/blob/main/Documentation/GettingStarted.md#updating-the-foundation-while-building-your-app).
- **Pin a tag, never a branch.** SemVer is CI-enforced since `1.0.0`, so `from:` is safe and minors never break you. A branch pin chases a moving commit with no contract.
- **`URLSession` retries dropped connections beneath Pal**, so one logical `send()` can hit your server more than once and `RetryInterceptor` multiplies that. Size rate limits and idempotency budgets accordingly.
- **Localization:** Pal products with user-facing text ship en + el via `Bundle.module` and accept custom strings, so you override without forking.

## Keep Pal's rules out of your app

Pal's own repository carries `AGENTS.md` files written for people working **on** Pal — "never add a dependency", "this is published API". When SPM checks Pal out into your build folder, an agent that opens a file there can pick those up and start applying foundation rules to your app code. Add this to your app's `.claude/settings.json`:

```json
{
  "permissions": { "deny": ["Read(./.build/**)"] },
  "claudeMdExcludes": ["**/.build/**", "**/SourcePackages/checkouts/**"]
}
```

## When Pal really is missing a mechanism

It goes in Pal's repo, not yours — [CONTRIBUTING](https://github.com/Mesrine23/pal-mvvm-foundation/blob/main/CONTRIBUTING.md). Additive changes ship in a minor and you bump one number. If you need it before the next release, fork and merge tags so you keep taking fixes.

## Where the detail lives

[Getting Started](https://github.com/Mesrine23/pal-mvvm-foundation/blob/main/Documentation/GettingStarted.md) — install → composition root → first feature · [Architecture](https://github.com/Mesrine23/pal-mvvm-foundation/blob/main/Documentation/ARCHITECTURE.md) — layers, the DAG, adoption notes · [Product guides](https://github.com/Mesrine23/pal-mvvm-foundation/tree/main/Documentation/Products) — full API per product · [DocC reference](https://mesrine23.github.io/pal-mvvm-foundation/) — every symbol · [CHANGELOG](https://github.com/Mesrine23/pal-mvvm-foundation/blob/main/CHANGELOG.md) — read the `Affects:` line and stop there if it isn't your products.
