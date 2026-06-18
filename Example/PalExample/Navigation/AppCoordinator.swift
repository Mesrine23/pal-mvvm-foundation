import SwiftUI
import PalNavigation

/// Owns the users-tab ``Router`` and turns screen navigation intents into pushes;
/// also the destination factory (one exhaustive switch over ``AppRoute``).
@MainActor
final class AppCoordinator: UsersListNavigationDelegate {

    /// The router driving the users tab's navigation stack.
    let router = Router<AppRoute>()

    private let container: AppContainer

    /// Creates the coordinator.
    /// - Parameter container: The composition root that builds ViewModels.
    init(container: AppContainer) {
        self.container = container
    }

    // MARK: - UsersListNavigationDelegate

    func showUserDetail(_ user: User) {
        router.push(.userDetail(user))
    }

    // MARK: - Destination factory

    /// Builds the screen for a route — compiler-enforced exhaustive switch.
    @ViewBuilder
    func view(for route: AppRoute) -> some View {
        switch route {
        case .usersList:
            UsersListView(viewModel: container.makeUsersListViewModel(delegate: self))
        case .userDetail(let user):
            UserDetailView(viewModel: container.makeUserDetailViewModel(user: user))
        }
    }
}
