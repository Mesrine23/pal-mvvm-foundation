import Observation
import PalAnalytics
import PalPresentation

/// Drives the users list: holds one ``Loader`` and delegates navigation.
@MainActor @Observable
final class UsersListViewModel {

    /// The users section's loadable state.
    let users = Loader<[User]>()

    @ObservationIgnored private let fetchUsers: any FetchUsersUseCaseProtocol
    @ObservationIgnored private let analytics: any AnalyticsTracker
    @ObservationIgnored private weak var delegate: (any UsersListNavigationDelegate)?

    /// Creates the ViewModel.
    init(
        fetchUsers: any FetchUsersUseCaseProtocol,
        analytics: any AnalyticsTracker,
        delegate: (any UsersListNavigationDelegate)?
    ) {
        self.fetchUsers = fetchUsers
        self.analytics = analytics
        self.delegate = delegate
    }

    /// Initial load — driven by the view's `.task` (awaitable, lifecycle-cancelled).
    func load() async {
        analytics.track(.screenViewed("users"))
        await users.performLoad { [fetchUsers] in
            try await fetchUsers.execute(forceRefresh: false)
        }
    }

    /// Pull-to-refresh — awaitable so the control's spinner waits for completion.
    func refresh() async {
        await users.performLoad { [fetchUsers] in
            try await fetchUsers.execute(forceRefresh: true)
        }
    }

    /// Retry from an error/empty state — fire-and-forget (re-trigger dedupe).
    func reload() {
        users.load { [fetchUsers] in
            try await fetchUsers.execute(forceRefresh: true)
        }
    }

    /// A row was tapped.
    func select(_ user: User) {
        analytics.track(.userSelected(id: user.id))
        delegate?.showUserDetail(user)
    }
}
