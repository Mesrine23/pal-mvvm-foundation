import PalNetworking
import PalPersistence
import PalAuth
import PalAnalytics
import PalFeatureFlags
import PalDebugKit
import PalNotifications
import PalWeb

/// The app's composition root — manual constructor injection, no DI framework.
/// One factory method per feature; dependencies are built once and shared.
@MainActor
final class AppContainer {

    /// App-wide UI state (theme branding).
    let appState: AppState

    /// The analytics seam (console-backed in the showcase).
    let analytics: any AnalyticsTracker

    /// The in-memory feature-flag provider, seeded at launch.
    let flags: InMemoryFeatureFlagsProvider

    /// The notifications facade — created at launch so it claims the
    /// notification-center delegate seat before cold-start taps arrive.
    let notifications = NotificationService()

    private let defaults = UserDefaultsService()
    private let cache = MemoryCache()
    private let tokenStore = KeychainTokenStore()
    private let usersRepo: any UsersRepoProtocol
    private let postsRepo: any PostsRepoProtocol

    init() {
        appState = AppState(defaults: defaults)
        analytics = ConsoleAnalyticsTracker()
        flags = InMemoryFeatureFlagsProvider(values: [FeatureFlag.showsUserEmail.key: true])

        #if DEBUGKIT
        PalDebugTools.shared.enable(environments: [
            APIEnvironment(name: "Production", baseURL: AppConfig.baseURL),
            APIEnvironment(name: "Localhost", baseURL: AppConfig.localhostURL),
        ])
        let interceptors: [any Interceptor] = [
            PalDebugTools.shared.inspectorInterceptor,
            PalDebugTools.shared.mockInterceptor,
            LoggingInterceptor(),
            RetryInterceptor(),
        ]
        let client = HTTPClient(
            baseURLProvider: { EnvironmentResolver.baseURL(for: .default, default: AppConfig.baseURL) },
            interceptors: interceptors
        )
        #else
        let client = HTTPClient(
            baseURL: AppConfig.baseURL,
            interceptors: [LoggingInterceptor(), RetryInterceptor()]
        )
        #endif
        usersRepo = UsersRepository(client: client, cache: cache)
        postsRepo = PostsRepository(client: client)
    }

    /// Builds the users-list ViewModel, injecting its navigation delegate.
    func makeUsersListViewModel(delegate: (any UsersListNavigationDelegate)?) -> UsersListViewModel {
        UsersListViewModel(
            fetchUsers: FetchUsersUseCase(usersRepo: usersRepo),
            analytics: analytics,
            delegate: delegate
        )
    }

    /// Builds the user-detail ViewModel for a selected user.
    func makeUserDetailViewModel(user: User) -> UserDetailViewModel {
        UserDetailViewModel(user: user, defaults: defaults, flags: flags, analytics: analytics)
    }

    /// Builds the paginated-posts ViewModel.
    func makePostsViewModel() -> PostsViewModel {
        PostsViewModel(fetchPage: FetchPostsPageUseCase(postsRepo: postsRepo), analytics: analytics)
    }

    /// Builds the settings ViewModel.
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            tokenStore: tokenStore,
            flags: flags,
            analytics: analytics,
            notifications: notifications,
            linkOpener: ExternalLinkOpener()
        )
    }

    /// Resolves a user by id for notification deep links (re-fetch in the destination).
    func user(withID id: Int) async throws -> User? {
        try await usersRepo.getUsers(forceRefresh: false).first { $0.id == id }
    }
}
