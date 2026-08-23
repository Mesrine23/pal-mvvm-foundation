# Pal — Agent Working Guide

Pal is a reusable, zero-dependency iOS foundation: one Swift Package, multiple library products, consumed by apps via SPM. Swift 6 strict concurrency · iOS 17 floor · MVVM + Coordinators · Clean layering (Presentation / Domain / Data).

**Canon:** [Documentation/DECISIONS.md](Documentation/DECISIONS.md) is the single source of truth for every locked decision. [Documentation/ARCHITECTURE.md](Documentation/ARCHITECTURE.md) explains structure and patterns. If anything here seems to conflict, DECISIONS.md wins. Do not relitigate locked decisions — propose changes to the owner instead.

**This file is canonical for agents.** `CLAUDE.md` is a one-line import of this file plus Claude-Code-only mechanics; never duplicate rules into it. Each area of the repo adds its own file, loaded when you work there:

| Editing | Also binding |
|---|---|
| `Sources/**` — foundation library code | [Sources/AGENTS.md](Sources/AGENTS.md) |
| `Example/**` — the showcase app (app-layer conventions) | [Example/AGENTS.md](Example/AGENTS.md) |
| `Tests/**` | [Tests/AGENTS.md](Tests/AGENTS.md) |
| `Documentation/**` | [Documentation/AGENTS.md](Documentation/AGENTS.md) |

**The repo also ships agent automation.** All of it is plain markdown and scripts — any agent can read it; Claude Code runs it automatically:

| Path | What it holds | Fires |
|---|---|---|
| [.claude/rules/](.claude/rules/) | Rules for files no directory file reaches: `Package.swift`, `CHANGELOG.md`, `.github/workflows/` | when that file is opened |
| [.claude/skills/](.claude/skills/) | Procedures: `/verify` (walks the definition of done), `/release` | on demand |
| [.claude/hooks/](.claude/hooks/) | Branch-policy guard · clean-code checker · session orientation | automatically |
| [.claude/settings.json](.claude/settings.json) | Pre-approved verify commands, generated-tree read denials, hook wiring | every session |
| [plugins/pal-adopter/](plugins/pal-adopter/) | The adopter kit — for agents in apps that *consume* Pal, never for work in this repo | installed by adopters |

## Build & verify

```bash
swift build        # all package targets
swift test         # smoke + targeted tests
# Example app: open Example/PalExample.xcodeproj (or xcodebuild -project ... -scheme PalExample)
```

Every change must leave `swift build` + `swift test` green **and** the Example app compiling. CI runs `swift build` + `swift test` on push to `main` and on every PR; the Example app is verified locally.

**CI builds on BOTH toolchain edges** (`macos-15` = Xcode 16 / Swift 6.1 — the consumer floor — and `macos-26` = the latest), plus an `api-stability` job. Newer SDKs concurrency-annotate system frameworks, so local green can hide strict-concurrency errors the floor hits — after touching any system-framework wrapper, check CI and fix with `@preconcurrency import <Framework>` (see the `v1.3.1` deviations entry):

```bash
gh run list --limit 5           # after pushing a system-framework change
```

A `Docs` workflow publishes DocC to GitHub Pages on release tags; every product has a curated `<Target>.docc` catalog — **add new public symbols to its Topics** when you extend a product.

## Definition of done

A change is finished only when every line below holds. Do not report completion otherwise; report what failed instead.

1. `swift build` exits 0.
2. `swift test` exits 0.
3. The Example app still compiles.
4. Every new public symbol carries a `///` doc comment **and** an entry in its product's `.docc` Topics.
5. Affected docs are updated **in the same change** — product guide, DECISIONS, ARCHITECTURE, CONTRIBUTING status (see [Documentation map](#documentation-map)).
6. If it ships in a release: a [CHANGELOG.md](CHANGELOG.md) entry exists, opening with an `Affects:` line.
7. If it touched `Documentation/ADOPTERS.md`, `plugins/`, or `.claude-plugin/`: `Scripts/check-adopter-kit.sh` exits 0.
8. The work sits on a pushed `feature/*` (or `hotfix/*`) branch — **not merged**.

## Never

Hard stops. If one of these looks necessary, stop and ask the owner.

- **Never merge a branch yourself.** Push the `feature/*`/`hotfix/*` branch and ask. Never commit features directly to `main`.
- **Never add a dependency** to `Package.swift`, and never add an edge to the [dependency DAG](#package-dependency-dag-enforced).
- **Never rename a foundation protocol to add a `…Protocol` suffix** (see [Naming conventions](#naming-conventions-scoped--binding)).
- **Never delete or rename a public symbol** pre-major — deprecate with `@available` and forward.
- **Never put a value in the foundation** — endpoints, user-facing strings, brand tokens, storage keys, analytics events, environments, validation rules. See [the law](#the-law-of-the-codebase).
- **Never relitigate a locked decision** in code or in these files; propose it to the owner and record the outcome in the deviations log.
- **Never leave `swift build`/`swift test` red** and call the work done.
- **Never disable or edit a hook to get a change through.** The hook is the rule; fix the code.

**Escalation:** if a fix fails twice, stop and report the failure with the actual output rather than working around it. When implementation reality conflicts with the design, surface the conflict and record the resolution in the [CONTRIBUTING](CONTRIBUTING.md) deviations log — the design text stays authoritative.

## The law of the codebase

**The foundation ships mechanisms; apps ship values.** Concrete endpoints, user-facing strings, brand tokens, storage keys, analytics events, environments, and validation rules NEVER live in Pal packages — apps supply them via typed keys, static factory extensions, and protocol conformances.

## Package dependency DAG (enforced — never add edges)

`PalCore→∅` · `PalPersistence→Core` · `PalNetworking→Core` · `PalAuth→Core,Networking,Persistence` · `PalPresentation→Core` · `PalNavigation→∅` · `PalDesignSystem→Core,Presentation` · `PalAnalytics→Core` · `PalFeatureFlags→Core` · `PalDebugKit→Core,Networking,Persistence` (not DesignSystem) · `PalNotifications→Core` · `PalWeb→Core,Presentation`.

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
10. Layer rules: Views never touch clients/repos; ViewModels import Domain + PalPresentation — plus PalDesignSystem **solely to own `AppAlert`/`AppToast` state** (the ACTION-channel values are ViewModel state by design; the chrome stays in Views); DTO↔entity mapping lives in Data; dependency arrows point inward.
11. Swift 6 hygiene: no `@unchecked Sendable` without written justification; `@MainActor` ViewModels; actors for shared mutable state.
12. Errors are never silently swallowed; mapped at boundaries (`NetworkError` → domain error → `PresentableError`); cancellation never surfaces to users.
13. **Reference types are `final` by default** — every class is `final` unless explicitly designed for subclassing (enables static dispatch, signals intent). Structs, enums, and actors need no annotation.

## The canonical per-screen pattern

Every screen: `@MainActor @Observable` ViewModel holding one or more `Loader<Value>` (each drives a `ViewState`: `idle / loading(previous:) / loaded / failed(error, previous:)`); call `loader.load { }` (auto-cancels the previous in-flight load, swallows cancellation, maps to `PresentableError`); the View switches on `viewModel.‹loader›.state`. Navigation goes through the screen's `NavigationDelegate`, implemented by the feature coordinator as one-liners over the typed `Router`. Dependencies arrive via `init` (constructor injection from the app-side factory). Load failures → `ViewState`; action failures → `.appAlert`; action confirmations → `.appToast`.

## Patterns & evolution (binding)

- **Delegation (child → owner):** when a child reports back to its owner (navigation, flow completion), use a `‹Context›Delegate` — `@MainActor`, `AnyObject`, held **weak**, intent-named. A closure for a one-shot callback; an `AsyncStream` for broadcast events (`AuthEvent`). See [DECISIONS §6](Documentation/DECISIONS.md).
- **Compatibility — open to extension, closed to modification:** the public API is a contract for the apps on Pal. Additive only; new protocol requirements ship with default impls; **deprecate (`@available`), never delete** pre-major; consumers track SemVer **tags**, never branches. Details and the `api-stability` gate: [Sources/AGENTS.md](Sources/AGENTS.md).
- **Source control:** GitFlow (`main` live/tagged · `develop` integration · `feature/*` off develop · `hotfix/*` off main → both). **Push the task branch and ask before merging.** Full policy in [CONTRIBUTING](CONTRIBUTING.md).
- **Releases:** a release is `develop → main` plus a SemVer tag, a CHANGELOG entry, and a GitHub Release. **Every CHANGELOG entry opens with an `Affects:` line** naming the products it touches (`Affects: documentation only` for a docs release). Derive the candidate list from the diff, then trim it to products whose public API or behavior actually changed:
  ```bash
  git diff --name-only <last-tag>..HEAD -- Sources | grep '\.swift$' | cut -d/ -f2 | sort -u
  ```

## Documentation map

- [Getting Started](Documentation/GettingStarted.md) — install → composition root → first feature.
- [Architecture](Documentation/ARCHITECTURE.md) — layers, the DAG, patterns, adoption notes.
- [Per-product guides](Documentation/Products/) — the API and usage of each product.
- [DECISIONS](Documentation/DECISIONS.md) — the design and its rationale (a living document, open to discussion).
- [CHANGELOG](CHANGELOG.md) — per-release changes, newest first; **every release adds an entry** (part of the release checklist).
- [ADOPTERS](Documentation/ADOPTERS.md) — the brief for agents working in apps built on Pal; canonical source for the `pal-adopter` plugin and `llms.txt`.
- [CONTRIBUTING](CONTRIBUTING.md) — build/verify, **implementation status & phase log**, and the deviations log.

**Status lives in CONTRIBUTING** (single source — do not restate it here, so it can't go stale). At a glance: all 12 products are built. **When you change an API, a decision, or a product's behavior, update the affected docs in the same change.**

## Maintaining these instruction files

These files are code, not prose. They are loaded into every agent session, so every line spends context budget and must earn it.

**Layout — one fact, one home.**

- `AGENTS.md` at the root is **canonical**: repo-wide rules, in the standard vendor-neutral format every coding agent reads.
- `CLAUDE.md` at the root is a **one-line `@AGENTS.md` import** plus Claude-Code-only mechanics. It must never restate a rule. (The two files were byte-identical mirrors until 2026-08-23; that duplication is deliberately gone — never reintroduce it.)
- `‹area›/AGENTS.md` + `‹area›/CLAUDE.md` pairs carry area-specific rules. Agents read the **nearest** file, so put a rule in the narrowest file that covers it. The nested `CLAUDE.md` is always exactly `@AGENTS.md`.

**Choosing a mechanism.** Five exist. Pick the narrowest one that fires when the rule actually matters:

| The rule applies… | Put it in |
|---|---|
| everywhere | root `AGENTS.md` |
| to one area of the tree | `‹area›/AGENTS.md` + its one-line `CLAUDE.md` |
| to specific files a directory can't isolate | `.claude/rules/‹topic›.md` with a `paths:` glob |
| as a multi-step procedure, run occasionally | `.claude/skills/‹name›/SKILL.md` |
| and must hold regardless of what an agent decides | `.claude/hooks/` — instructions are context, not enforcement |

`AGENTS.md` files are read by every coding agent; `.claude/` is honored automatically only by Claude Code. **Never let `.claude/` be the sole home of a binding rule** — it carries operational detail, procedure, and enforcement, and each piece links back to the rule it serves.

**Budget.** Root file ≤ ~200 lines; each nested file ≤ ~80. Past that, adherence drops and cost rises. If a section outgrows its budget, push the detail down into the nested file or out into `Documentation/` and leave a link.

**Write rules an agent can execute.**

- Imperative and specific: "run `swift test` before reporting done", not "test your changes".
- Command-first: state the command that proves the rule was followed. A rule with no verification is a suggestion.
- No hedging words — "be careful", "where possible", "handle gracefully" change no behavior.
- No contradictions. Two rules that disagree get resolved arbitrarily; the narrower file wins over the root, and DECISIONS wins over both.

**Keep out.** Anything derivable from the codebase (directory listings, file inventories, dependency versions) · status and history (→ CONTRIBUTING) · rationale (→ DECISIONS) · consumer API usage (→ Documentation/Products) · anything stale next week.

**When to update.** Edit these files in the same change that makes them true:

- An agent made the same mistake twice, or a review caught something an agent should have known.
- A build/test/CI command changed, or a `Never` stopped being true.
- A binding rule changed — **change [DECISIONS.md](Documentation/DECISIONS.md) first** (owner approval), then ripple here. These files mirror DECISIONS §4–5; they never lead it.
- At every release tag, re-read this file against the CHANGELOG entry.
- After a major model release, delete workarounds a newer model no longer needs.

**Before you commit a change to these files:**

1. Nothing was dropped — moved content landed in a named file, and the file that lost it links there.
2. No rule is stated twice across the root and nested files.
3. Every command in the file was actually run and exits 0.
4. Every relative link resolves.
5. `CONTRIBUTING.md`'s pointer to these files still matches reality.
6. A changed hook was run against a sample payload, and a changed skill's frontmatter still parses.
