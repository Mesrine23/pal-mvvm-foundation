# Getting Started

> From zero to a running feature on Pal. Read [Architecture](ARCHITECTURE.md) for the *why*; this is the *how*.

## Requirements

- **iOS 17+** deployment target · **Swift 6** (strict concurrency) · Xcode 16+.
- Pal has **zero external dependencies**. Swinject (if you use it) is an app-side choice, never pulled in by Pal.

## 1. Add the package

In Xcode: **File ▸ Add Package Dependencies…**, enter the repository URL, and pin to a version. Or in your own `Package.swift`:

```swift
dependencies: [
    // SemVer since 1.0.0: minors and patches never break. Track tags, never a branch.
    .package(url: "https://github.com/Mesrine23/pal-mvvm-foundation.git", from: "1.0.0"),
],
targets: [
    .target(name: "App", dependencies: [
        .product(name: "PalCore", package: "pal-mvvm-foundation"),
        .product(name: "PalNetworking", package: "pal-mvvm-foundation"),
        .product(name: "PalPresentation", package: "pal-mvvm-foundation"),
        .product(name: "PalNavigation", package: "pal-mvvm-foundation"),
        // …add only the products you need
    ]),
]
```

Import only what you use. Each product declares its own dependencies (the [DAG](ARCHITECTURE.md#package-map)); you never get more than you ask for.

> **Multi-target apps:** a Pal product linked to the *app* target is not visible to separate framework targets. Each framework that imports a Pal product must link it directly (e.g. your Data framework links `PalNetworking`). Domain links nothing — it stays pure Swift.

## 2. The app shell (the ~15% a package can't ship)

A package can't provide `@main`, the root scene, `Info.plist`, entitlements, or your composition root. You write those once:

```swift
import SwiftUI

@main
struct MyApp: App {
    @State private var container = AppContainer()
    var body: some Scene {
        WindowGroup { RootView(container: container) }
    }
}
```

## 3. The composition root

Wire dependencies in one place. Manual constructor injection needs no DI framework:

```swift
import PalNetworking

@MainActor
final class AppContainer {
    private let client: NetworkClient = HTTPClient(baseURL: AppConfig.baseURL)
    private lazy var usersRepo: UsersRepoProtocol = UsersRepository(client: client)

    func makeUsersListViewModel(delegate: UsersListNavigationDelegate?) -> UsersListViewModel {
        UsersListViewModel(fetchUsers: FetchUsersUseCase(usersRepo: usersRepo), delegate: delegate)
    }
    // one factory method per feature; grows as the app grows
}
```

Larger apps can use Swinject (native `Assembly`/`Assembler`, single root container) instead — see [Architecture](ARCHITECTURE.md). Either way: **factories resolve dependencies and constructor-inject ViewModels.**

## 4. Your first feature (the canonical vertical slice)

Every feature follows the same shape. Build it once and the pattern repeats.

**Domain — pure Swift (no networking, no UI):**

```swift
struct User: Sendable, Identifiable, Equatable { let id: Int; let name: String }

protocol UsersRepoProtocol: Sendable { func getUsers() async throws -> [User] }

protocol FetchUsersUseCaseProtocol: Sendable { func execute() async throws -> [User] }
struct FetchUsersUseCase: FetchUsersUseCaseProtocol {
    let usersRepo: UsersRepoProtocol
    func execute() async throws -> [User] { try await usersRepo.getUsers() }
}
```

**Data — DTO + request factory + repository (maps DTO → entity):**

```swift
import PalNetworking

struct UserDTO: Decodable, Sendable {
    let id: Int; let full_name: String
    var toDomain: User { User(id: id, name: full_name) }
}
extension Request { static func users() -> Request<[UserDTO]> { .init(path: "/users") } }

struct UsersRepository: UsersRepoProtocol {
    let client: NetworkClient
    func getUsers() async throws -> [User] { try await client.send(.users()).map(\.toDomain) }
}
```

**Presentation — ViewModel holds a `Loader`; View switches on its state:**

```swift
import PalPresentation

@MainActor @Observable
final class UsersListViewModel {
    let users = Loader<[User]>()
    private let fetchUsers: FetchUsersUseCaseProtocol
    private weak var delegate: UsersListNavigationDelegate?

    init(fetchUsers: FetchUsersUseCaseProtocol, delegate: UsersListNavigationDelegate?) {
        self.fetchUsers = fetchUsers; self.delegate = delegate
    }
    func load() async { await users.performLoad { try await self.fetchUsers.execute() } }
    func refresh() { users.load { try await self.fetchUsers.execute() } }   // retry button
    func userTapped(_ user: User) { delegate?.showUserDetail(user) }
}
```

```swift
import SwiftUI
import PalPresentation
import PalDesignSystem

struct UsersListView: View {
    @State var viewModel: UsersListViewModel
    var body: some View {
        Group {
            switch viewModel.users.state {
            case .idle, .loading(previous: nil):    LoadingView()
            case .loading(previous: let users?):    list(users).overlay { ProgressView() }
            case .loaded(let users):                list(users)
            case .failed(let error, previous: nil): ErrorView(error) { viewModel.refresh() }
            case .failed(_, previous: let users?):  list(users)   // + banner over stale data
            }
        }
        .task { await viewModel.load() }
    }
    func list(_ users: [User]) -> some View {
        List(users) { user in Button(user.name) { viewModel.userTapped(user) } }
    }
}
```

That's the whole loop: **View → ViewModel → UseCase → Repository → NetworkClient**, dependencies pointing inward to Domain.

### Multiple calls, one state

When a screen fires several calls and you only care once they're **all done**, don't track several loaders — return a **composite** from a composing use case and hold a single `Loader<Composite>`:

```swift
struct DashboardContent: Sendable { let profile: Profile; let feed: [Post]; let balance: Balance }

struct LoadDashboardUseCase: LoadDashboardUseCaseProtocol {
    let profileRepo: any ProfileRepoProtocol
    let feedRepo: any FeedRepoProtocol
    let balanceRepo: any BalanceRepoProtocol

    func execute() async throws -> DashboardContent {
        async let profile = profileRepo.getProfile()   // independent → run in parallel
        async let feed    = feedRepo.getFeed()
        async let balance = balanceRepo.getBalance()
        return try await DashboardContent(profile: profile, feed: feed, balance: balance)
    }
}
```
```swift
@MainActor @Observable
final class DashboardViewModel {
    let dashboard = Loader<DashboardContent>()
    private let load: any LoadDashboardUseCaseProtocol
    init(load: any LoadDashboardUseCaseProtocol) { self.load = load }
    func refresh() { dashboard.load { try await self.load.execute() } }
}
// View switches on one `viewModel.dashboard.state` — the same single switch as a one-call screen.
```

`async let` runs the calls concurrently; `try await DashboardContent(…)` returns only when **all** finish, and if any throws, structured concurrency cancels the rest and the one loader goes `.failed`.

- **One loader + composite** when you care "all done together" (independent calls → `async let`; data-dependent → sequential `await`, inside the use case — the VM and View don't change).
- **A loader per section** only when sections load/fail/**refresh independently**. The moment a section reloads on its own, give *that* section its own `Loader` and drop it from the composite (one source of truth); derive "all done on init" as a computed `isInitiallyLoading`, and refresh just that section with `section.refresh { … }` (its `.loading(previous:)` keeps the stale data while it reloads).
- A spinner for a true **action** (submit/toggle), not a content section, belongs on a separate `Loader<Void>`/flag with errors via `.appAlert` — the ACTION channel, distinct from LOAD.

### Paginated lists

When the list arrives in pages, swap the `Loader` for a **`PagedLoader`** — the accumulated items drive the same `ViewState`, so the screen's `switch` is unchanged. The trigger is **the trailing footer row that sits outside the `ForEach`**, firing when it appears:

```swift
@MainActor @Observable
final class PostsViewModel {
    let posts: PagedLoader<Post, Int>
    init(fetchPage: any FetchPostsPageUseCaseProtocol) {
        posts = PagedLoader { page in
            let current = page ?? 1                              // nil = first page
            let result = try await fetchPage.execute(page: current)
            return Page(items: result.posts, nextCursor: result.hasMore ? current + 1 : nil)
        }
    }
    func loadMore() { posts.loadMore() }
}
```
```swift
List {
    ForEach(posts) { post in PostRow(post) }     // the rows
    if viewModel.posts.hasMore {                 // the paging footer — OUTSIDE the ForEach
        ProgressView()
            .frame(maxWidth: .infinity)
            .id(posts.count)                     // fresh identity per page: re-fires onAppear
            .onAppear { viewModel.loadMore() }   //   when a short page keeps it visible
    }
}
```

- `loadMore()` is **self-deduping** — the eager `onAppear` can fire freely; it no-ops mid-flight, before the first page, and after the last.
- A **failed load-more keeps the list**: render `posts.loadMoreError` in the footer (e.g. `SectionErrorView`) with retry = `loadMore()` again. Only first-page failures reach `ViewState.failed`.
- The Example app's Posts tab is this pattern end-to-end. (`.onReachedBottom` in DesignSystem is a generic `ScrollView` geometry utility — in `List`/lazy stacks, the appearance-based footer above is the pattern.)

## 5. Navigation

Define a typed route, render with `RouterView`, and let the ViewModel delegate intents. The full per-feature shape — route enum + coordinator + destination factory — is the **coordinator triangle** in [PalNavigation](Products/PalNavigation.md):

```swift
import PalNavigation

enum UsersRoute: Routable { case list; case detail(User) }

RouterView(router: router, root: .list) { route in   // `root` is a Route case — the stack's base screen
    switch route {
    case .list:             UsersListView(/* … */)
    case .detail(let user): UserDetailView(/* … */)
    }
}
```

## 6. Optional wiring

- **Auth refresh** — supply a `TokenRefreshService`, use `KeychainTokenStore` ([PalAuth](Products/PalAuth.md)), build a `TokenProvider`, add `AuthInterceptor`. See [PalNetworking](Products/PalNetworking.md).
- **Analytics / flags** — register `NoOp…` by default; swap to real providers at the composition root. See [PalAnalytics](Products/PalAnalytics.md) / [PalFeatureFlags](Products/PalFeatureFlags.md).
- **Theming** — works with `Theme.system` out of the box; brand with `.theme(myTheme)`. See [PalDesignSystem](Products/PalDesignSystem.md).
- **Notifications** — create one `NotificationService` at the composition root (claims the delegate seat for cold-start taps); schedule typed `LocalNotification`s (fire-now or scheduled), forward APNs callbacks from a 5-line `UIApplicationDelegateAdaptor`, and route taps via the `responses` stream. See [PalNotifications](Products/PalNotifications.md).
- **Web pages** — embed terms/help/docs with `WebScreen` + a navigation policy (yours decides what stays in and what opens externally); `ExternalLinkOpener` for non-View contexts. OAuth stays in `ASWebAuthenticationSession`, app-side. See [PalWeb](Products/PalWeb.md).
- **Debug tools** — shake to open `PalDebugKit` (network logs, env switcher, mocks); wire it behind your app's `DEBUGKIT` flag at the composition root. See [PalDebugKit](Products/PalDebugKit.md).

## Updating the foundation while building your app

You'll inevitably hit a gap in the foundation while building a real app. Here's how to change it correctly.

**The one rule:** a version-pinned dependency is checked out **read-only** into DerivedData (`…/SourcePackages/checkouts/`). Never edit there — those changes are untracked and get wiped on the next resolve. Updating the foundation always means editing the **real repo**; the only question is how the app sees your edits.

### Option A — Local override (edit live) — for tight iteration

1. Clone the foundation locally.
2. In the app's Xcode window, drag the foundation folder into the Project Navigator (or *File ▸ Add Package Dependencies… ▸ Add Local…*). The local copy **overrides the remote pin** — the app now builds against your source.
3. Edit the foundation **in the same workspace**, live — no commit or version bump needed to test. Run its `swift test` as you go.
4. When happy: **commit + push + tag** the foundation (new SemVer), **remove the override**, and **bump the app's pin** to the new tag.

### Option B — Versioned release, then bump the pin — for a discrete change

Make the change in the foundation repo on its own → `swift test` → **commit + push + tag** (e.g. `v1.1.0`) → in the app, *File ▸ Packages ▸ Update to Latest Package Versions* (or raise the version requirement) → commit the app's updated `Package.resolved`.

### Option C — Track a branch/commit — for an early-stage app

Pin the dependency to a **branch** (e.g. `main`) or a specific commit instead of a version, push to the foundation, and *Update Packages*. No tag per tweak. Switch back to version pins once things stabilize.

### The loop, in one line

App pins a **version** → hit a gap → add the **local override** and edit live → verify in the app + `swift test` → **commit/push/tag** the foundation → **remove the override** → **bump the pin** → commit `Package.resolved`.

### Gotchas

- **Remove the local override before you ship or push the app** — otherwise it builds against a local path that doesn't exist on CI or another machine.
- **Commit `Package.resolved`** so app builds are reproducible.
- **SemVer is the contract:** since `1.0.0`, a breaking change ships only in a *major* — deprecations first — so **`from:` is safe**; minors and patches never break you (CI enforces it with an API-stability gate). **Track tags, never a branch** (a branch pin chases a moving commit with no contract).
- **One direction only:** changes flow *into* the foundation repo and *out* to apps via versions — never edit two divergent copies.

## Where to go next

- [Architecture](ARCHITECTURE.md) — layers, the DAG, patterns, adoption notes.
- [Per-product guides](Products/) — the full API of each product.
- [Design decisions](DECISIONS.md) — why Pal is shaped the way it is (open to discussion).
