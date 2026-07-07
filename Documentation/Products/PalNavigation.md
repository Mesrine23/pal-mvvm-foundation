# PalNavigation

> Typed, payload-carrying routes over `NavigationStack`, with a `Router` ViewModels delegate to, nested-stack modals, and deep links. Zero `AnyView`, no view caching, no DI types. Dependencies: none.

`import PalNavigation`

## What it gives you

- **`Routable`** — your route enum (`Hashable & Sendable`) with **payloads in the cases**.
- **`Router<Route>`** — `@MainActor @Observable`; a typed `[Route]` path plus modal presentation.
- **`RouterView<Route, Destination>`** — wraps `NavigationStack` + `navigationDestination` + modal bindings.
- **Deep links** — `DeepLinkHandler` → `DeepLinkResult { routes, strategy }`.

## Define routes with payloads

```swift
import PalNavigation

enum UsersRoute: Routable {
    case list                // the stack's base screen — passed to RouterView as `root`
    case detail(User)        // payload rides the route — no "courier" registration
    case settings
}
```

## Router API

```swift
let router = Router<UsersRoute>()

router.push(.detail(user))
router.pop()                       // pop(_ count: Int = 1)
router.pop(to: .settings)
router.popToRoot()
router.replace(with: [.settings])
router.navigate(to: [.detail(a), .detail(b)], strategy: .append)   // .replace | .append

// Modals (a journey with its own screens):
let child = router.present(.detail(user), style: .sheet)   // returns the child Router
child.push(.settings)              // the modal has its own stack
router.dismiss()                   // dismiss presented modal
router.dismissSelf()               // a child dismisses itself via its parent link
```

## Render with RouterView

```swift
RouterView(router: router, root: .list) { route in    // `root` is a Route case (the stack's base screen)
    switch route {                 // exhaustive — compiler-enforced; renders the root route too
    case .list:             UsersListView(viewModel: factory.list())
    case .detail(let user): UserDetailView(viewModel: factory.detail(user))
    case .settings:         SettingsView()
    }
}
```

`RouterView` puts the router in the environment, binds `.sheet(item:)` / `.fullScreenCover(item:)` (presentations are **Identifiable items, never booleans**), and gives each modal its **own** nested `RouterView`/stack.

## ViewModels navigate via an intent-named delegate

Keep navigation out of the ViewModel; delegate it (the feature coordinator implements these as one-liners over the `Router`):

```swift
@MainActor protocol UsersListNavigationDelegate: AnyObject {
    func showUserDetail(_ user: User)
}
// in the VM: delegate?.showUserDetail(user)
```

## The coordinator triangle (per feature)

The full per-feature shape is **route enum + coordinator + destination factory**, wired once at the tab root — `RouterView`'s destination closure is the factory seam the foundation ships:

```swift
// 1. The coordinator — owns the Router; implements the screens' delegates as one-liners.
@MainActor
final class UsersCoordinator: UsersListNavigationDelegate {
    let router = Router<UsersRoute>()
    func showUserDetail(_ user: User) { router.push(.detail(user)) }
}

// 2. The destination factory — the ONLY type that touches the container/resolver;
//    one exhaustive switch, constructor-injecting each screen's ViewModel.
@MainActor
struct UsersDestinationFactory {
    let container: AppContainer

    @ViewBuilder
    func view(for route: UsersRoute, delegate coordinator: UsersCoordinator) -> some View {
        switch route {
        case .list:             UsersListView(viewModel: container.makeUsersListViewModel(delegate: coordinator))
        case .detail(let user): UserDetailView(viewModel: container.makeUserDetailViewModel(user: user))
        case .settings:         SettingsView()
        }
    }
}

// 3. Wired once at the tab root.
struct UsersTab: View {
    @State private var coordinator = UsersCoordinator()
    let factory: UsersDestinationFactory

    var body: some View {
        RouterView(router: coordinator.router, root: .list) { route in
            factory.view(for: route, delegate: coordinator)
        }
    }
}
```

- ViewModels hold their delegate **weak**, so someone must own the coordinator — `@State` at the tab root (or a parent coordinator) keeps it alive.
- **A small feature may merge the factory into the coordinator** (one `view(for:)` on the coordinator — the Example app's `AppCoordinator` does exactly this). Split them the moment the switch or the DI wiring grows; the split type keeps the `‹Feature›DestinationFactory` name.
- The **Coordinator** Xcode template (`Templates/Xcode/`) scaffolds the merged shape.

## Deep links

```swift
struct AppDeepLinks: DeepLinkHandler {
    func result(for url: URL) -> DeepLinkResult<AppRoute>? {
        switch url.lastPathComponent {
        case "checkout": DeepLinkResult(routes: [.checkout], strategy: .append)   // protect in-progress state
        default:         nil
        }
    }
}
```

`.replace` resets the stack; `.append` preserves in-progress user state (half-written form + a push tap).

## Modal policy (hybrid)

- **Screen-local UI modals** (filters/pickers that need `Binding`s into the presenting VM) stay **view-level**.
- **Multi-screen flow modals** (checkout, onboarding, auth-expired → login) go through `router.present(_:)` with a nested `RouterView`.

Rule of thumb: *modal edits the presenting screen's state → view-level; modal is a journey with its own screens → router.*

## Notes

- Ownership: the app shell holds the root coordinator (`@State`) → the coordinator owns its `Router` → `RouterView` **receives** it (never creates it).
- Route payloads are entities (not IDs); that is deliberate and trades away state-restoration friendliness.
- **When the destination can edit its payload's entity, treat the payload as a seed:** the destination ViewModel copies it into its own state at `init` and replaces it after successful saves — the route value is just the initial snapshot. (The ID-in-route + re-fetch variant remains the alternative when staleness matters more broadly.)
- Composition: one `Router` per tab; cross-feature navigation via an app-level enum wrapping feature routes (`AppRoute.users(UsersRoute)`).

See also: [Architecture](../ARCHITECTURE.md) · [Getting Started](../GettingStarted.md)
