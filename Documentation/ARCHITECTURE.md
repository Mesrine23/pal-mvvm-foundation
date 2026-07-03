# Pal — Architecture

> How the foundation is structured and how apps build on it — this document explains shape and patterns; the decisions and their rationale live in [DECISIONS.md](DECISIONS.md). To start building, see [Getting Started](GettingStarted.md); for each product's API, the [per-product guides](Products/).

## Layers

```
┌─────────────────────────────────────────────────────────┐
│ Presentation   View (SwiftUI) → ViewModel (@Observable) │  imports Domain only
├─────────────────────────────────────────────────────────┤
│ Domain         Entities · Repo protocols · Use cases    │  pure Swift, imports nothing
├─────────────────────────────────────────────────────────┤
│ Data           DTOs · Request factories · Repositories  │  imports Domain + PalNetworking
└─────────────────────────────────────────────────────────┘
        all dependency arrows point inward to Domain
```

- The network decodes **DTOs**; the repository maps DTO → entity. Domain never sees `Decodable` or HTTP.
- ViewModels receive use cases via `init` (constructor injection). Views never touch clients or repositories.

## Package map

```
PalCore ──────────────┐
   ▲                  │ (no SwiftUI in Core)
   │                  │
PalPersistence   PalNetworking   PalPresentation   PalNavigation
        ▲             ▲               ▲                (no deps)
        └── PalAuth ──┘               │
                                PalDesignSystem
PalAnalytics · PalFeatureFlags · PalNotifications (→ Core)
PalDebugKit (→ Core, Networking, Persistence)
PalWeb (→ Core, Presentation)
```

| Product | Role |
|---|---|
| `PalCore` | LoggerFactory (os.Logger), curated Foundation extensions, Debouncer/withTimeout, AppInfo, AppLanguage |
| `PalPersistence` | KeychainService (throwing), UserDefaultsService, typed keys (`KeychainKey`/`DefaultsKey`), MemoryCache (actor, passive TTL, memory-only) |
| `PalNetworking` | `Request<Response>`, `HTTPClient` (typed `throws(NetworkError)`), interceptor onion over `TransportRequest`, `TokenProvider` single-flight refresh actor |
| `PalAuth` | `KeychainTokenStore` glue (TokenStore ⇄ KeychainService) + `BiometricAuthenticator` (Face ID/Touch ID, typed outcomes) |
| `PalPresentation` | `ViewState<Value>`, `PresentableError`, `Loader<Value>` (the owned per-section runner) |
| `PalNavigation` | `Routable`, `Router<Route>`, `RouterView`, deep-link strategies, Identifiable modal items |
| `PalDesignSystem` | Opt-in Theme (system default), `.textStyle`, ErrorView/SectionErrorView/EmptyStateView/LoadingView, `.appAlert`, SwiftUI utilities, en+el catalogs |
| `PalAnalytics` / `PalFeatureFlags` | Provider-agnostic seams + NoOp/Console/Composite/InMemory impls |
| `PalDebugKit` | Shake debug menu (overlay window): network Logs, API environment switcher, Mocks — runtime-enabled, gated app-side by the `DEBUGKIT` flag |
| `PalNotifications` | `NotificationService`: permission, local scheduling (immediate/delayed/calendar), APNs token plumbing, tap-response + push-event streams, foreground policy, categories |
| `PalWeb` | `WebScreen` (WKWebView) driving a `WebPageModel`'s `ViewState`, app-supplied navigation policy (allow/cancel/open-externally) |

Each product has a usage guide in [Documentation/Products/](Products/).

## The canonical vertical slice

```swift
// DOMAIN — pure
public struct User: Sendable, Identifiable, Equatable { public let id: Int; public let name: String }

public protocol UsersRepoProtocol: Sendable {
    func getUsers() async throws -> [User]
}

public protocol FetchUsersUseCaseProtocol: Sendable {
    func execute() async throws -> [User]
}
public struct FetchUsersUseCase: FetchUsersUseCaseProtocol {
    private let usersRepo: UsersRepoProtocol
    public init(usersRepo: UsersRepoProtocol) { self.usersRepo = usersRepo }
    public func execute() async throws -> [User] { try await usersRepo.getUsers() }
}

// DATA — DTO + request factory + repository
struct UserDTO: Decodable, Sendable {
    let id: Int
    let full_name: String
    func toDomain() -> User { User(id: id, name: full_name) }
}
extension Request {
    static func users() -> Request<[UserDTO]> { .init(path: "/users") }
}
struct UsersRepository: UsersRepoProtocol {
    let client: NetworkClient
    func getUsers() async throws -> [User] { try await client.send(.users()).map { $0.toDomain() } }
}

// PRESENTATION — ViewModel + View
@MainActor protocol UsersListNavigationDelegate: AnyObject {
    func showUserDetail(_ user: User)
}

@MainActor @Observable
final class UsersListViewModel {
    let users = Loader<[User]>()             // one Loader per independently-loadable section
    private let fetchUsers: FetchUsersUseCaseProtocol
    private weak var delegate: UsersListNavigationDelegate?

    init(fetchUsers: FetchUsersUseCaseProtocol, delegate: UsersListNavigationDelegate?) {
        self.fetchUsers = fetchUsers
        self.delegate = delegate
    }

    func refresh() { users.load { try await self.fetchUsers.execute() } }
    func userTapped(_ user: User) { delegate?.showUserDetail(user) }
}
// View switches on `viewModel.users.state`.

// COMPOSITION ROOT (app shell, @MainActor) — manual constructor injection:
@MainActor
final class AppContainer {
    private let client: NetworkClient = HTTPClient(baseURL: AppConfig.baseURL)
    private lazy var usersRepo: UsersRepoProtocol = UsersRepository(client: client)

    func makeUsersListViewModel(delegate: UsersListNavigationDelegate?) -> UsersListViewModel {
        UsersListViewModel(fetchUsers: FetchUsersUseCase(usersRepo: usersRepo), delegate: delegate)
    }
    // one factory method per feature; grows as the app grows
}
// Swinject is the alternative for larger apps (native Assembly/Assembler, single
// root container) — factories resolve + constructor-inject and `resolve(...)!`
// is the sanctioned fail-fast. The manual container above needs no DI framework.
```

## Key patterns

**Multi-call screens** — a composing use case returns a composite model; `async let` for independent calls, plain `await` where data-dependent; one `loader.load {}` in the VM (or one `Loader` per independent section).

**Partial failure** — optional topics typed `Result<Value, PresentableError>` inside the composite; View renders content or `SectionErrorView` per topic; critical call still throws.

**Pagination** — `PagedLoader` accumulates pages into one `ViewState` (the screen's switch is unchanged). The trigger is the trailing footer row **outside the `ForEach`**, firing `loadMore()` on appearance — `.id(items.count)` re-arms it when a short page keeps it visible. A failed load-more keeps the list (footer retry); only first-page failures reach `ViewState.failed`. `.onReachedBottom` is a generic scroll utility, not the pagination trigger.

**Failure channels** — LOAD failures drive `ViewState.failed` (full error screen or banner over stale data); ACTION failures (screen keeps its data) drive `.appAlert`.

**Delegation (child → owner)** — when a child reports back to the owner that presents it (navigation, flow completion), use a `‹Context›Delegate`: `@MainActor protocol …: AnyObject`, held **weak**, intent-named methods (`showUserDetail(_:)`, `checkoutDidFinish(_:)`). Prefer it over passing closures or `Binding`s upward. Use a **closure** for a single one-shot callback, and an **`AsyncStream`** for broadcast events (why `AuthEvent.loggedOut` is a stream, not a delegate).

**Modals (hybrid)** — screen-local UI modals (pickers/filters; need Bindings into the presenting VM) stay view-level; multi-screen flow modals (checkout/onboarding/auth-expired) go through `router.present(_:)` with a nested `RouterView`. Presentations are Identifiable items, never booleans.

**Deep links** — `DeepLinkHandler` maps URL → routes + strategy; `.append` protects in-progress user state, `.replace` resets. The push-launch flow is just "set the path".

**Notifications** — one `NotificationService` at the composition root; creating it claims the delegate seat, so cold-start taps are captured (buffered until `responses` is first observed). Taps become routes at the root: `userInfo` carries an **id**, the coordinator re-fetches and pushes. APNs tokens arrive via a ~5-line app-side `UIApplicationDelegateAdaptor` forwarding into the service; provider SDKs stay app-side.

**Pull-to-refresh** — drive it from `Loader.refresh(_:)` (reloads in place — no `.loading` transition, since the refresh control is the indicator), not `performLoad`. And keep the scrollable (`List`) mounted: render empty/error as **overlays** rather than `switch`-ing the `List` out for an `EmptyStateView`/`ErrorView`. Flipping `.loading` or swapping the scrollable while `.refreshable` is still spinning fights the refresh control ("change the refresh control while it is not idle") and drops the first update. The initial-load `LoadingView` swap is fine (no refresh control yet).

**Caching** — repository-level cache-aside via `MemoryCache` (`forceRefresh:` bypass, per-key TTL, passive expiry, `clear()` on logout). Never HTTP-level.

**Local mutation (re-fetch after write)** — a local store has no `@Query`, so after a `create`/`update`/`delete` through the repository, **re-fetch** to reflect the change (the coordinator calls the list VM's `refresh()` on return). One source of truth, read path unchanged. See *Local persistence* under [Adopting Pal](#adopting-pal-in-an-existing-app).

**Auth refresh** — `AuthInterceptor` injects the Bearer token and, on 401, awaits `TokenProvider.refresh()` (single-flight actor: N concurrent 401s → one refresh) and retries once. `AuthEvent.loggedOut` streams to the root coordinator → present login flow.

**DebugKit gating** — package code always compiles; activation is runtime + default-OFF. Apps define the `DEBUGKIT` compilation condition in the configurations that should carry tools and wrap `PalDebugTools.enable(…)` + Inspector/Mock wiring in `#if DEBUGKIT` at the composition root. SPM builds packages in release mode for any non-"Debug" app configuration — the package can never self-gate per configuration; this is why the flag lives in the app.

## Adopting Pal in an existing app

- **Repositories back onto any source — not just the network.** The repository is the only layer that touches storage; back it with `UserDefaultsService` / SwiftData / Core Data / a bundled file / in-memory. For a synchronous, non-failing local source the `ViewState` `loading`/`failed` cases are largely vestigial — still use a `Loader` for uniformity (its `load { }` closure is `async throws`, so wrap a sync call as `load { store.get(...) }`), or skip the loader and hold the value directly when a screen truly can't load or fail.
- **Local relational stores (SwiftData/Core Data) live app-side, behind repositories.** Pal ships no persistence-framework dependency (zero-deps), but the pattern that fits Swift 6 cleanly is: make the repository a **`@ModelActor`** — it is `Sendable`, owns its `ModelContext` off the main actor, and is built from the `Sendable` `ModelContainer`, so it drops into a nonisolated DI closure and its `async` methods satisfy a `Sendable` repo protocol and feed `Loader`'s `@Sendable` operation with no isolation friction. **Map `@Model` reference types → pure `Sendable` domain structs inside the actor**, so only value types cross back to the `@MainActor` ViewModel. There is no `@Query` by design — after a write, re-fetch through the repository (see *Local mutation* above). For instant, non-failing local reads the `Loader` `.loading`/`.failed` cases are largely vestigial — keep `Loader` for uniformity, or hold the value directly (first bullet).
- **Modularize app layers as local SPM packages (recommended) — or framework targets.** The cleanest way to enforce the layer DAG is to put Domain/Data in **local Swift packages** (one package with library products, or one package per layer), exactly how Pal itself ships — Presentation/app then physically *cannot* import a `@Model` or a repository impl, turning the dependency rule into a **compile-time** guarantee. SPM library targets also default to **`nonisolated`** isolation, precisely what the Swift-6 note below prescribes for Domain/Data (a single app target instead forces them to the app's `MainActor` default — the opposite). Gotchas on this path: types crossing a package boundary need `public` (+ public inits) — encapsulate persistence behind a public facade + domain protocols, keep `@Model`s `internal`; **watch name collisions** once a module imports SwiftData (a module named `Data` clashes with `Foundation.Data`; a `Category` type clashes with the ObjC runtime — use `RecipesData` / `RecipeCategory`); add a `.macOS` floor so `swift build`/tests run on the host. The older approach — separate framework **`.xcodeproj`** targets — also works: a Pal product linked to the *app* target is **not** visible to a framework target, so each framework links the Pal products it imports directly (Domain links nothing — it stays pure Swift).
- **Existential domains can't be route payloads.** `Routable` requires `Hashable & Sendable`, so an `any SomeProtocol` existential can't ride a route. Model the domain as a concrete (sum) type, **or** carry an ID in the route and re-fetch in the destination (also the state-restoration-friendly variant).
- **Swift 6 / Xcode 26 actor isolation.** Set Domain/Data targets to `nonisolated` default isolation and the app/Presentation target to `MainActor` (`SWIFT_DEFAULT_ACTOR_ISOLATION`). Otherwise entity/content types silently become main-actor-isolated and can't be constructed off-actor inside `Loader`'s `@Sendable` operation ("main actor-isolated … cannot be called from outside the actor"). Entity/content types must be `Sendable`. Under that `MainActor` default, **pure constants/utilities consumed by nonisolated code must be marked `nonisolated`** — e.g. a design-token constant used as a default argument inside a custom `Layout`, or a `Sendable` helper called off-actor — or they inherit `MainActor` and become unreachable from the nonisolated context.

## Workflows

- **Live-edit Pal while building an app:** drag the local Pal checkout into the app's workspace (local override beats the remote pin) → edit live → commit/push/tag → remove override → bump the app's pin.
- **Phases:** implementation proceeds per the [phase log in CONTRIBUTING](../CONTRIBUTING.md); every phase ends with `swift build` + `swift test` green and the Example app compiling.
