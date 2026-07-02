import Foundation
import Testing
@testable import PalNavigation
#if canImport(SwiftUI)
import SwiftUI
#endif

enum TestRoute: Routable {
    case list
    case detail(Int)
    case settings
}

@MainActor
@Suite("Router")
struct RouterTests {

    @Test("Push and pop manage the typed path")
    func pushAndPop() {
        let router = Router<TestRoute>()

        router.push(.detail(1))
        router.push(.settings)
        #expect(router.path == [.detail(1), .settings])

        router.pop()
        #expect(router.path == [.detail(1)])
    }

    @Test("Pop beyond the stack depth is safe")
    func popBeyondDepthIsClamped() {
        let router = Router<TestRoute>()
        router.push(.settings)

        router.pop(5)

        #expect(router.path.isEmpty)
    }

    @Test("popToRoot empties the stack")
    func popToRoot() {
        let router = Router<TestRoute>()
        router.push(.detail(1))
        router.push(.detail(2))

        router.popToRoot()

        #expect(router.path.isEmpty)
    }

    @Test("pop(to:) returns to the most recent occurrence")
    func popToRoute() {
        let router = Router<TestRoute>()
        router.replace(with: [.detail(1), .settings, .detail(2), .settings])

        router.pop(to: .detail(2))

        #expect(router.path == [.detail(1), .settings, .detail(2)])
    }

    @Test("pop(to:) with an absent route is a no-op")
    func popToAbsentRoute() {
        let router = Router<TestRoute>()
        router.replace(with: [.settings])

        router.pop(to: .detail(9))

        #expect(router.path == [.settings])
    }

    @Test("navigate(strategy: .replace) resets the stack")
    func navigateReplace() {
        let router = Router<TestRoute>()
        router.push(.settings)

        router.navigate(to: [.detail(1), .detail(2)], strategy: .replace)

        #expect(router.path == [.detail(1), .detail(2)])
    }

    @Test("navigate(strategy: .append) protects the existing stack")
    func navigateAppend() {
        let router = Router<TestRoute>()
        router.push(.settings)

        router.navigate(to: [.detail(7)], strategy: .append)

        #expect(router.path == [.settings, .detail(7)])
    }

    @Test("present stores an Identifiable modal with style and child router")
    func presentStoresModal() {
        let router = Router<TestRoute>()

        let child = router.present(.settings, style: .fullScreenCover)

        #expect(router.presentedModal?.route == .settings)
        #expect(router.presentedModal?.style == .fullScreenCover)
        #expect(router.presentedModal?.childRouter === child)
        #expect(child.parent === router)
    }

    @Test("Dismiss-then-present yields a NEW identity (the auth-expired→login scenario)")
    func dismissThenPresentChangesIdentity() {
        let router = Router<TestRoute>()

        router.present(.settings)
        let firstID = router.presentedModal?.id
        router.dismiss()
        router.present(.settings)
        let secondID = router.presentedModal?.id

        #expect(router.presentedModal != nil)
        #expect(firstID != secondID)
    }

    @Test("dismissSelf from the child closes the whole flow on the parent")
    func dismissSelfClosesFlow() {
        let router = Router<TestRoute>()
        let child = router.present(.settings)
        child.push(.detail(1))

        child.dismissSelf()

        #expect(router.presentedModal == nil)
    }

    @Test("A deep-link result applies routes with its strategy")
    func deepLinkResultApplies() {
        let router = Router<TestRoute>()
        router.push(.settings)
        let result = DeepLinkResult<TestRoute>(routes: [.detail(3)], strategy: .append)

        router.navigate(to: result.routes, strategy: result.strategy)

        #expect(router.path == [.settings, .detail(3)])
    }

    #if canImport(SwiftUI)
    @Test("RouterView doc snippet compiles — requires the root: route")
    func routerViewDocSnippetCompiles() {
        let router = Router<TestRoute>()
        _ = RouterView(router: router, root: .list) { route in
            switch route {
            case .list:           Text("list")
            case .detail(let id): Text("detail \(id)")
            case .settings:       Text("settings")
            }
        }
    }

    @Test("The coordinator-triangle doc snippet compiles (coordinator + factory + RouterView)")
    func coordinatorTriangleDocSnippetCompiles() {
        let coordinator = TriangleCoordinator()
        let factory = TriangleDestinationFactory()
        _ = RouterView(router: coordinator.router, root: .list) { route in
            factory.view(for: route, delegate: coordinator)
        }
        coordinator.showDetail(7)
        #expect(coordinator.router.path == [.detail(7)])
    }
    #endif
}

#if canImport(SwiftUI)
@MainActor private protocol TriangleNavigationDelegate: AnyObject {
    func showDetail(_ id: Int)
}

/// Mirrors PalNavigation.md's "coordinator triangle": the coordinator owns the
/// Router and implements the delegate; the factory holds the exhaustive switch.
@MainActor private final class TriangleCoordinator: TriangleNavigationDelegate {
    let router = Router<TestRoute>()
    func showDetail(_ id: Int) { router.push(.detail(id)) }
}

@MainActor private struct TriangleDestinationFactory {
    @ViewBuilder
    func view(for route: TestRoute, delegate coordinator: TriangleCoordinator) -> some View {
        switch route {
        case .list:           Text("list")
        case .detail(let id): Text("detail \(id)")
        case .settings:       Text("settings")
        }
    }
}
#endif
