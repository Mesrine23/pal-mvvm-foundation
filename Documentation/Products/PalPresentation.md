# PalPresentation

> The per-screen contract every ViewModel uses: a four-case state, a presentable error, and an owned async runner. Kills the per-VM flag-zoo (`isLoading` / `showError` / `errorMessage` …). Dependencies: PalCore.

`import PalPresentation`

## What it gives you

- **`ViewState<Value>`** — `idle` · `loading(previous:)` · `loaded(Value)` · `failed(PresentableError, previous:)`. The `previous` payload keeps content on screen during refresh and failed-refresh.
- **`PresentableError`** — `title`, `message`, `isRetryable`; map domain errors via `PresentableErrorConvertible`.
- **`Loader<Value>`** — a `@MainActor @Observable` runner the ViewModel **holds** (one per independently-loadable section). It owns the in-flight `Task`, the state transitions, and cancellation.

## The canonical per-screen pattern

```swift
import PalPresentation

@MainActor @Observable
final class UsersListViewModel {
    let users = Loader<[User]>()                 // one Loader per loadable section
    private let fetchUsers: FetchUsersUseCaseProtocol

    init(fetchUsers: FetchUsersUseCaseProtocol) { self.fetchUsers = fetchUsers }

    func refresh() { users.load { try await self.fetchUsers.execute() } }
}
```

```swift
// The View switches on the loader's state:
switch viewModel.users.state {
case .idle, .loading(previous: nil):           LoadingView()
case .loading(previous: let value?):           content(value).overlay { ProgressView() }
case .loaded(let value):                       content(value)
case .failed(let error, previous: nil):        ErrorView(error) { viewModel.refresh() }
case .failed(let error, previous: let value?): content(value)   // + banner over stale data
}
```

`state` helpers: `value`, `isLoading`, `error`.

## What `Loader.load { }` does for you

- Cancels the previous in-flight load (re-trigger dedupe — search-as-you-type, rapid refresh).
- Sets `.loading(previous:)`, then `.loaded` or `.failed(PresentableError, previous:)`.
- **Swallows `CancellationError`** (cancellation never reaches the user).
- Holds `self` weakly; `state` is `private(set)` (only the loader mutates it).

Variants: `performLoad { } async` for `.task { }` (view-lifecycle cancellation); `refresh { } async` for `.refreshable { }` (reloads **in place** — no `.loading` transition, since the refresh control is already the spinner); `cancel()` for teardown (keeps the state — nobody is looking); and `reset()` for a **user-facing Cancel button** (cancels AND returns to `.idle`, so no spinner is stranded on a screen that stays visible). Rule of thumb: **the runner owns re-trigger cancellation; `.task` owns lifecycle cancellation.**

## Mapping your errors

```swift
enum UserError: Error, PresentableErrorConvertible {
    case notFound, network
    var presentableError: PresentableError {
        switch self {
        case .notFound: PresentableError(title: "Not found", message: "…", isRetryable: false)
        case .network:  .generic
        }
    }
}
```

`Loader` maps anything thrown into a `PresentableError` (using your conformance when present, else `.generic`). For **ACTION paths outside a loader** (save/delete handlers), the same mapping is public — `PresentableError(from: error)` — so never hand-roll the conformance-or-generic dance:

```swift
do { try await deleteUser.execute(id) }
catch { alert = .error(PresentableError(from: error)) }
```

## Multi-section & partial failure

Hold **several** `Loader`s on one ViewModel for independently-loadable sections. For one composite call where a topic may fail without failing the screen, model fields as `Result<Value, PresentableError>` and render an inline `SectionErrorView` (see [PalDesignSystem](PalDesignSystem.md)).

## Pagination: `PagedLoader`

`Loader`'s sibling for infinite lists — the accumulated items drive the **same** `ViewState` switch, and pages append through a footer-sized side channel:

```swift
@MainActor @Observable
final class PostsViewModel {
    let posts: PagedLoader<Post, Int>
    init(fetchPosts: FetchPostsUseCaseProtocol) {
        posts = PagedLoader { page in try await fetchPosts.execute(page: page ?? 1) }
    }
}
```

- The operation is **injected at `init`** (deliberate asymmetry vs `Loader`): the loader re-invokes it with successive cursors — `nil` means first page; your `Page(items:nextCursor:)` supplies the next cursor (`nil` = the end, disarming `hasMore`).
- First page = the familiar trio: `load()` / `performLoad()` (for `.task`) / `refresh()` (pull-to-refresh, no `.loading`, restarts from page one).
- **`loadMore()`** appends the next page — fire-and-forget, self-deduping (no-ops while any fetch is in flight, before the first page, or after the last). Trigger it from the appearance of the **trailing footer row that sits outside the `ForEach`** — the canonical pattern, shown in [Getting Started](../GettingStarted.md). **`performLoadMore() async`** is the awaitable sibling (same guards and transitions) for tests, tools, and prefetching flows that need to await completion instead of polling `isLoadingMore`.
- **A failed load-more never touches the list**: items stay, `loadMoreError` drives an inline footer retry (which just calls `loadMore()` again — it clears the error). Only first-page failures go through `ViewState.failed`.
- Footer contract: `isLoadingMore` → spinner · `loadMoreError` → retry · `hasMore == false` → nothing (or an end-of-list note).

## Editor screens: fetch with a Loader, edit a draft

High-frequency editors (steppers, toggles, text fields mutating dozens of times a minute) must **not** route every change through `Loader.load` — the loader is a read-screen runner. The pattern:

```swift
@MainActor @Observable
final class RequirementsViewModel {
    let initial = Loader<WeekConfig>()          // the INITIAL fetch only
    var draft = WeekConfig.empty                // UI truth — synchronous, bindable

    @ObservationIgnored private var saveQueue: Task<Void, Never>?

    func draftChanged() {                       // persist snapshots, ordered
        let snapshot = draft
        saveQueue = Task { [previous = saveQueue] in
            await previous?.value                // chain: order preserved, last write wins
            try? await save(snapshot)            // route real failures to .appAlert
        }
    }
}
```

- The `Loader` handles the initial fetch (and seeds `draft` on `.loaded`); from then on **the draft is the single UI truth** — no flag-zoo creeps back in through editors.
- Chaining each save `Task` onto the previous one preserves write order without an actor queue.
- A plain form modal that edits the *presenting* screen's state needs no loader at all — see the modal policy in [PalNavigation](PalNavigation.md).

## Optional content: model absence as a case

`Loader<Value?>` nests optionals (`previous` becomes `Value??`) and breaks the copy-paste five-case switch. When "not there yet" is a **legitimate loaded state** (a week not configured, a profile not created), make absence a domain case instead:

```swift
enum WeekContent: Sendable { case notConfigured; case configured(WeekConfig) }
let week = Loader<WeekContent>()   // the switch stays flat; absence renders a call-to-action
```

## Reloading on return (re-fetch after write)

After a pushed screen writes and pops back, the list refreshes via **the view's `.onAppear` with an already-loaded guard** — `onAppear` fires again on every return to a screen, and the guard keeps the first load's skeleton/`LoadingView` path untouched:

```swift
func reloadOnReturn() {
    guard users.state.value != nil else { return }   // first load owns .task
    users.load { try await self.fetchUsers.execute() }
}
// in the View: .onAppear { viewModel.reloadOnReturn() }
```

## Notes

- Channel split: **LOAD** failures → `ViewState` (full error or banner over stale data); **ACTION** failures (screen keeps its data) → `.appAlert` (DesignSystem). A ViewModel owning `alert: AppAlert?` / `toast: AppToast?` imports PalDesignSystem for exactly that — the **blessed shape** (layer rule 10).
- Default strings for `PresentableError` ship localized (en + el); override per error as needed.

See also: [PalDesignSystem](PalDesignSystem.md) (renders these states) · [Architecture](../ARCHITECTURE.md)
