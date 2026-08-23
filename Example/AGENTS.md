# Example — the showcase app

Extends [../AGENTS.md](../AGENTS.md). `PalExample` consumes the package by local path and dogfoods every product: a Users slice (list → detail over a public API), a paginated Posts list (`PagedLoader` + skeleton loading), and Settings (theming, a feature flag, a demo Keychain session, notifications, an embedded About web page, app info).

**This is the only app-layer code in the repo**, so the app-layer half of the naming conventions (`…UseCaseProtocol`, `…RepoProtocol` → `…Repository`, `…NavigationDelegate`) applies *here and nowhere else*. Never carry those suffixes into `Sources/`.

It is also the reference implementation of the canonical per-screen pattern — when the pattern changes, this app changes with it.

## Verify

```bash
# open Example/PalExample.xcodeproj, or:
xcodebuild -project Example/PalExample.xcodeproj -scheme PalExample build
```

The app must compile before any change is done. It builds for the iOS Simulator with 0 warnings — keep it that way.

## Layout

`Domain/` entities + use cases · `Data/` DTOs, mapping, repositories · `Features/{Users,Posts,Settings}/` screens · `Navigation/` coordinators + routes · `Composition/` the composition root · `Analytics/`, `FeatureFlags/` app-side conformances.

## Main-actor default isolation

The app target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Domain and Data value types are therefore marked `nonisolated` so DTOs decode and entities construct off the main actor. New entities, DTOs, and use-case types follow suit — this is the adoption guidance in [ARCHITECTURE.md](../Documentation/ARCHITECTURE.md), not an Example-only quirk.

## Composition root

`Composition/AppContainer.swift` wires everything by hand (manual DI — Swinject is only mentioned as an app-side option, never linked here). This is the one place a force-unwrap is allowed, and only for DI resolution: fail-fast by design.

## DebugKit

PalDebugKit is wired behind the `DEBUGKIT` compilation condition (`SWIFT_ACTIVE_COMPILATION_CONDITIONS`), with `PalDebugTools.enable(…)` plus the Inspector/Mock interceptor wiring inside `#if DEBUGKIT` at the composition root. That is the recipe apps copy — keep it copyable.

## Dogfooding is part of shipping a mechanism

A new public mechanism in `Sources/` is not finished until something here uses it. That is how the API gets exercised before adopters meet it, and how the guides' snippets stay honest.

## Adding a product to the app target

Each Pal product is linked into the app target in `project.pbxproj`; source files themselves are picked up automatically by Xcode's synchronized file groups, so new files need no project edit — new *products* do.
