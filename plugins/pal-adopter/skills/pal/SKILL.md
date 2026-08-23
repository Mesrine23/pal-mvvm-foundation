---
name: pal
description: Conventions for an app built on the Pal iOS foundation — mechanisms vs values, the ViewState/Loader screen shape, app-layer naming, and which of the twelve products to reach for. Use when working in an app that imports PalCore, PalNetworking, PalPresentation, PalNavigation, PalDesignSystem, or any other Pal product.
---

# Building on Pal

**Pal ships mechanisms; your app ships values.** Base URLs, user-facing strings, brand colors, storage keys, analytics event names, environments, and validation rules are supplied by the app through typed keys, static factory extensions, and protocol conformances. Never change Pal to supply a value, and never assume a value belongs in Pal — when a task feels like "Pal is missing something", check whether it is a value first.

## Screen state

A screen's state comes from a `Loader<Value>` held by a `@MainActor @Observable` ViewModel, driving a `ViewState` the View switches on: `idle / loading(previous:) / loaded / failed(error, previous:)`. Do not add `isLoading` flags or error booleans alongside it.

- `loader.load { }` — fire and forget; cancels the previous in-flight load, swallows cancellation, maps failures to `PresentableError`.
- `loader.performLoad { }` — the awaitable form, for `.task { }` and tests.
- `loader.refresh { }` — reload in place without entering `.loading` (pull-to-refresh, where the control is the indicator).
- `PagedLoader` for paginated lists; the accumulated items drive the same `ViewState`, so the View's switch is unchanged.

**Several calls that finish together = one `Loader` over a composite value**, produced by a composing use case with `async let`. A section gets its own `Loader` only when it reloads independently.

**Three channels, never mixed:** load failures → `ViewState` · action failures → `.appAlert` · action confirmations → `.appToast`.

## Naming

App-layer seams take explicit suffixes; Pal's own API never does.

| Seam | Protocol | Implementation |
|---|---|---|
| Use case | `‹Verb›‹Entity›UseCaseProtocol` (one method, `execute(...)`) | `‹Verb›‹Entity›UseCase` |
| Repository | `‹Entity›RepoProtocol` | `‹Entity›Repository` |
| Navigation | `‹Screen›NavigationDelegate`, intent-named methods | the feature coordinator |

Never write `NetworkClientProtocol`, `TokenStoreProtocol`, or `RouterProtocol` — Pal's types already carry their final names.

## Wiring

Dependencies reach a ViewModel through `init`, from a factory method on the app's composition root. Pal ships no DI framework and no global state; a shared store is a small `@MainActor @Observable` object over `UserDefaultsService` typed keys, created once by the container and injected like anything else.

## Before you reach for a Pal change

A pinned dependency is checked out **read-only** — edits inside `SourcePackages/checkouts/` or `.build/` are untracked and vanish on the next resolve. Pin a tag, never a branch.

## Depth

`reference/ADOPTERS.md` in this plugin is the full adopter brief: the product-selection table, the gotchas list, and the settings snippet that keeps Pal's contributor rules out of your app. Read it when you need more than the conventions above. Full API docs: <https://mesrine23.github.io/pal-mvvm-foundation/>.
