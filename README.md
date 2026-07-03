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

## Install

In Xcode: **File ▸ Add Package Dependencies…**, paste the repo URL, pin a version, and import the products you need. The full walkthrough — install → composition root → first feature — is in **[Getting Started](Documentation/GettingStarted.md)**.

## Documentation

- **[Getting Started](Documentation/GettingStarted.md)** — from zero to a running feature.
- **[Architecture](Documentation/ARCHITECTURE.md)** — layers, the dependency DAG, patterns, adoption notes.
- **[Per-product guides](Documentation/Products/)** — the API and usage of each product.
- **[Design decisions](Documentation/DECISIONS.md)** — why Pal is shaped the way it is.
- **[Contributing](CONTRIBUTING.md)** — build/verify, the binding conventions, and the deviations log.

## Develop

```bash
swift build && swift test
```

The `Example/` app is a runnable showcase: it consumes the package via a local path and dogfoods the products — a canonical Users slice (list → detail over a public API), a paginated Posts list (`PagedLoader` + skeleton loading), and a Settings screen (theming, a feature flag, a demo Keychain session, a notifications demo, app info).

Xcode file templates for scaffolding use cases, view models, and coordinators live in [`Templates/Xcode/`](Templates/Xcode/) — see its README to install them.
