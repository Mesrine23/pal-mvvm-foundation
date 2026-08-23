# Pal

A reusable, **zero-dependency** iOS foundation — one Swift Package, multiple focused products — built on **Swift 6** strict concurrency, **iOS 17+**, **MVVM + Coordinators**, and **Clean** layering (Presentation / Domain / Data).

> **The law of the codebase:** the foundation ships **mechanisms**; apps ship **values**. Concrete endpoints, user-facing strings, brand tokens, storage keys, analytics events, environments, and validation rules never live in Pal — apps supply them via typed keys, static factories, and protocol conformances.

## Products

| Product | What it gives you | Guide |
|---|---|---|
| `PalCore` | Logging, curated extensions, async utilities, `AppInfo`, `AppLanguage` | [→](Documentation/Products/PalCore.md) |
| `PalPersistence` | Keychain & UserDefaults services with typed keys, in-memory TTL cache | [→](Documentation/Products/PalPersistence.md) |
| `PalNetworking` | Typed `Request<Response>` client, interceptor pipeline, single-flight auth refresh | [→](Documentation/Products/PalNetworking.md) |
| `PalAuth` | Keychain-backed token-store glue | [→](Documentation/Products/PalAuth.md) |
| `PalPresentation` | `ViewState`, `PresentableError`, the `Loader` runner | [→](Documentation/Products/PalPresentation.md) |
| `PalNavigation` | Typed routes, `Router`, `RouterView`, deep links, flow modals | [→](Documentation/Products/PalNavigation.md) |
| `PalDesignSystem` | Opt-in theming, text styles, state views, alerts (en + el) | [→](Documentation/Products/PalDesignSystem.md) |
| `PalAnalytics` | Provider-agnostic analytics seam + no-op/console/composite | [→](Documentation/Products/PalAnalytics.md) |
| `PalFeatureFlags` | Synchronous feature-flag seam + in-memory/no-op | [→](Documentation/Products/PalFeatureFlags.md) |
| `PalDebugKit` | Shake-to-debug: network logs, environment switcher, mocks | [→](Documentation/Products/PalDebugKit.md) |
| `PalNotifications` | Push + local notifications: permission, scheduling, APNs plumbing, tap routing | [→](Documentation/Products/PalNotifications.md) |
| `PalWeb` | Embedded web pages with `ViewState` + navigation policy, external-browser opener | [→](Documentation/Products/PalWeb.md) |

## Install

```swift
// Xcode ▸ File ▸ Add Package Dependencies…, or in your own Package.swift:
.package(url: "https://github.com/Mesrine23/pal-mvvm-foundation.git", from: "1.5.0"),
```

Import only the products you need — each declares its own dependencies, so you never link more than you ask for. **Pin a tag, never a branch**, and don't copy the sources into your project: SemVer is CI-enforced since `1.0.0`, so `from:` is safe and an upgrade is one number. The full walkthrough — install → composition root → first feature — is in **[Getting Started](Documentation/GettingStarted.md)**.

### When you need something Pal doesn't do

**It's a value → you don't touch Pal.** Base URLs, brand tokens, storage keys, analytics events, environments, validation rules, and every user-facing string are supplied *by the app* through typed keys, static factory extensions, and protocol conformances. That's the law above, and it's the answer most of the time — the [product guides](Documentation/Products/) show the seam for each one.

**It's a mechanism → edit the foundation, in its own repo.** A pinned dependency is checked out **read-only** into DerivedData; edits there are untracked and vanish on the next resolve. [Updating the foundation while building your app](Documentation/GettingStarted.md#updating-the-foundation-while-building-your-app) covers the local-override loop (edit Pal and your app live in one Xcode window), the versioned-release loop, and the gotchas. Then [Contributing](CONTRIBUTING.md): branch off `develop`, keep `swift build` + `swift test` green, add a [CHANGELOG](CHANGELOG.md) entry, tag.

**You need it today and can't wait for a release** → fork, add this repo as `upstream`, and merge tags periodically so you keep taking fixes.

## Building on Pal with a coding agent

Point your agent at **[the adopter brief](Documentation/ADOPTERS.md)** — the conventions it needs in one page: mechanisms vs values, the `Loader`/`ViewState` screen shape, app-layer naming, and the gotchas that cost the most time. Paste it into your app's `AGENTS.md`, or install the plugin and skip the copy:

```bash
/plugin marketplace add Mesrine23/pal-mvvm-foundation
/plugin install pal-adopter@pal-foundation
```

Details, including how to enable it for everyone on your app in one commit, are in [`plugins/pal-adopter/`](plugins/pal-adopter/). Agents with web access can also start from [`llms.txt`](https://mesrine23.github.io/pal-mvvm-foundation/llms.txt) on the docs site.

## Documentation

- **[API reference (DocC)](https://mesrine23.github.io/pal-mvvm-foundation/)** — symbol-level docs for every product, browsable on the web (or *Product ▸ Build Documentation* in Xcode).
- **[Getting Started](Documentation/GettingStarted.md)** — from zero to a running feature.
- **[Architecture](Documentation/ARCHITECTURE.md)** — layers, the dependency DAG, patterns, adoption notes.
- **[Per-product guides](Documentation/Products/)** — the API and usage of each product.
- **[Design decisions](Documentation/DECISIONS.md)** — why Pal is shaped the way it is.
- **[Changelog](CHANGELOG.md)** — what each release added.
- **[Adopter brief](Documentation/ADOPTERS.md)** — the one-page agent brief for apps built on Pal.
- **[Contributing](CONTRIBUTING.md)** — build/verify, the binding conventions, and the deviations log.

## Develop

```bash
swift build && swift test
```

The `Example/` app is a runnable showcase: it consumes the package via a local path and dogfoods the products — a canonical Users slice (list → detail over a public API), a paginated Posts list (`PagedLoader` + skeleton loading), and a Settings screen (theming, a feature flag, a demo Keychain session, a notifications demo, an embedded About web page, app info).

Xcode file templates for scaffolding use cases, view models, and coordinators live in [`Templates/Xcode/`](Templates/Xcode/) — see its README to install them.
