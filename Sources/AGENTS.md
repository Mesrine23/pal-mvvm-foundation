# Sources — foundation library code

Extends [../AGENTS.md](../AGENTS.md). Everything here is published API: twelve products that apps link against by SemVer tag. Assume every symbol you touch is already compiled into someone's app.

## The public API is a contract

*Open to extension, closed to modification.*

- **Evolve additively.** New types, new methods, new overloads beside the existing ones, and new protocol requirements **only with default implementations** — a bare new requirement breaks every conformer in every app.
- **A new parameter on an existing init or method is a break, even with a default.** Calls still compile, but the old signature is gone and the gate reports it removed — add an overload beside it instead (the `ThemeColors.init` precedent, DECISIONS §14).
- **An overload that differs only in its return type passes the gate but breaks callers:** existing calls become ambiguous. Give the new method its own name.
- **Deprecate, don't delete.** Keep the old symbol and forward it; remove only at a major, a release after the deprecation:
  ```swift
  @available(*, deprecated, renamed: "send(_:)")
  public func execute<R>(_ request: Request<R>) async throws(NetworkError) -> R { try await send(request) }
  ```
- **Mind enums.** Adding a `case` to a public enum is source-breaking (consumer `switch`es are exhaustive) — reserve case additions for a major.
- **SemVer mapping:** additive → minor · fix → patch · breaking → major (with deprecations first).

Verify before you claim additivity — both runs, against the latest release tag:

```bash
BASELINE=$(git tag --list 'v*' --sort=-v:refname | head -1)
swift package diagnose-api-breaking-changes "$BASELINE"
swift package --triple arm64-apple-ios17.0-simulator --sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" diagnose-api-breaking-changes "$BASELINE"
```

The host build compiles out `#if canImport(UIKit)` code, so only the second run sees UIKit-only API (in PalDebugKit, PalDesignSystem, PalNotifications and PalWeb). Trust a run only when it lists all twelve products. CI runs both as the `api-stability` job, but its iOS run warns and skips until GitHub's image carries an Xcode that can diff an iOS build (26.6 can't), so run the second command yourself; a deliberate break is the one expected red. Its failure semantics are in [.claude/rules/ci-workflows.md](../.claude/rules/ci-workflows.md).

## DocC catalogs

Each product owns `Sources/<Target>/<Target>.docc`. **Adding a public symbol means adding it to that catalog's Topics in the same change** — an uncurated symbol still appears, just unorganized, which is visible decay. Cross-module symbols use plain code voice in doc comments; DocC links resolve only within a module. The catalogs are built plugin-free (`xcodebuild docbuild` in CI) so `Package.swift` keeps its zero-dependency guarantee.

## Platform & framework boundaries

- **PalCore is Foundation-only** — no SwiftUI, no UIKit, no StoreKit.
- UIKit appears only behind `#if canImport(UIKit)`, in PalDebugKit (shake detection + the above-everything overlay window), PalNotifications, and PalWeb. Adding UIKit to another product needs owner approval.
- The macOS 14 platform floor in `Package.swift` exists only so the host can build and test; products target iOS.

## Required-reason APIs

`Sources/PalCore/PrivacyInfo.xcprivacy` and `Sources/PalPersistence/PrivacyInfo.xcprivacy` declare the required-reason APIs those products touch (PalCore's exists because `AppLanguage` writes `AppleLanguages` via UserDefaults — CA92.1). Adding a required-reason API to any product means adding or creating that product's manifest in the same change.

## Localization

PalDesignSystem and PalPresentation ship String Catalogs via `Bundle.module` in **en + el** and read their named keys without symbols (`String(localized: "common.ok", bundle: .module)`), since the Xcode 16 floor generates none. They accept optional custom strings so apps override without forking. PalDebugKit's UI is developer-facing and English-only, with no catalog.
