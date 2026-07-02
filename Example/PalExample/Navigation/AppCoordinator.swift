import os
import SwiftUI
import PalCore
import PalNavigation
import PalNotifications

/// Owns the users-tab ``Router`` and turns screen navigation intents into pushes;
/// also the destination factory (one exhaustive switch over ``AppRoute``).
@MainActor
final class AppCoordinator: UsersListNavigationDelegate {

    /// The router driving the users tab's navigation stack.
    let router = Router<AppRoute>()

    private let container: AppContainer
    private let logger = LoggerFactory.make(category: "Navigation")

    /// Creates the coordinator.
    /// - Parameter container: The composition root that builds ViewModels.
    init(container: AppContainer) {
        self.container = container
    }

    // MARK: - UsersListNavigationDelegate

    func showUserDetail(_ user: User) {
        router.push(.userDetail(user))
    }

    // MARK: - Notification deep link

    /// Routes a notification tap: `userInfo` carries a `userID`, we re-fetch the
    /// user (the ID-on-route variant) and push their detail.
    func handleNotification(_ response: NotificationResponse) {
        guard let idText = response.userInfo["userID"], let id = Int(idText) else { return }
        Task {
            do {
                guard let user = try await container.user(withID: id) else { return }
                router.popToRoot()
                router.push(.userDetail(user))
            } catch {
                logger.error("Notification deep link failed: \(error)")
            }
        }
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
