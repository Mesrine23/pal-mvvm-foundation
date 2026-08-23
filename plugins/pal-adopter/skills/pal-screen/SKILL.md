---
name: pal-screen
description: Add a screen to an app built on Pal, following the canonical vertical slice — Domain, Data, ViewModel with a Loader, View switching on ViewState, route, navigation delegate, and container factory. Use when adding or scaffolding a new screen, feature, or list/detail flow in a Pal app.
argument-hint: [screen name]
---

Build the slice in this order. Each layer only knows the one inside it: **View → ViewModel → UseCase → Repository → client**.

## 1. Domain

An entity plus one use case, both `nonisolated` under a main-actor-default app target (see `reference/ADOPTERS.md`).

```swift
nonisolated struct Item: Identifiable, Hashable, Sendable { let id: Int; let title: String }

nonisolated protocol FetchItemsUseCaseProtocol: Sendable { func execute() async throws -> [Item] }
nonisolated struct FetchItemsUseCase: FetchItemsUseCaseProtocol {
    let itemsRepo: ItemsRepoProtocol
    func execute() async throws -> [Item] { try await itemsRepo.getItems() }
}
```

One method per use case, always `execute(...)`.

## 2. Data

DTO, a `Request` factory extension, and the repository that maps DTO → entity. Mapping never leaks upward.

```swift
extension Request { static func items() -> Request<[ItemDTO]> { .init(path: "/items") } }
```

For a local app, the repository wraps a `@ModelActor` over SwiftData instead of a `NetworkClient`, and returns domain structs — same seam.

## 3. ViewModel

```swift
@MainActor @Observable
final class ItemsViewModel {
    let items = Loader<[Item]>()
    private let fetchItems: FetchItemsUseCaseProtocol
    private weak var delegate: ItemsNavigationDelegate?

    init(fetchItems: FetchItemsUseCaseProtocol, delegate: ItemsNavigationDelegate?) {
        self.fetchItems = fetchItems
        self.delegate = delegate
    }

    func load() async { await items.performLoad { try await self.fetchItems.execute() } }
    func refresh() { items.load { try await self.fetchItems.execute() } }
    func itemTapped(_ item: Item) { delegate?.showItemDetail(item) }
}
```

The delegate is `weak` and `AnyObject`. No `isLoading`, no error flag — the `Loader` holds both.

## 4. View

Switch on the state; one `.task` to load. User-facing text comes from the String Catalog, never a literal.

```swift
switch viewModel.items.state {
case .idle, .loading(previous: nil):    LoadingView()          // or a .skeleton row
case .loading(previous: let items?):    list(items).overlay { ProgressView() }
case .loaded(let items):                list(items)
case .failed(let error, previous: nil): ErrorView(error) { viewModel.refresh() }
case .failed(_, previous: let items?):  list(items)            // stale data + a banner
}
```

## 5. Navigation

Add the route case, declare the delegate next to the ViewModel, and implement it on the feature coordinator as one-liners over the typed `Router`.

```swift
enum ItemsRoute: Routable { case list; case detail(Item) }

@MainActor protocol ItemsNavigationDelegate: AnyObject { func showItemDetail(_ item: Item) }
```

## 6. Composition root

One factory method, constructor-injecting everything:

```swift
func makeItemsViewModel(delegate: ItemsNavigationDelegate?) -> ItemsViewModel {
    ItemsViewModel(fetchItems: FetchItemsUseCase(itemsRepo: itemsRepo), delegate: delegate)
}
```

## Before you call it done

Every user-facing string is a catalog key · the delegate is weak · the View owns no business logic and touches no client or repository · an action's failure goes to `.appAlert` and its confirmation to `.appToast`, not to the screen's `ViewState`.
