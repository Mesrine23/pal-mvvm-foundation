import PalNetworking
import PalPersistence
import PalAuth
import PalAnalytics
import PalFeatureFlags

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

    private let defaults = UserDefaultsService()
    private let cache = MemoryCache()
    private let tokenStore = KeychainTokenStore()
    private let usersRepo: any UsersRepoProtocol

    init() {
        appState = AppState(defaults: defaults)
        analytics = ConsoleAnalyticsTracker()
        flags = InMemoryFeatureFlagsProvider(values: [FeatureFlag.showsUserEmail.key: true])

        let client = HTTPClient(
            baseURL: AppConfig.baseURL,
            interceptors: [LoggingInterceptor(), RetryInterceptor()]
        )
        usersRepo = UsersRepository(client: client, cache: cache)
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

    /// Builds the settings ViewModel.
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(tokenStore: tokenStore, flags: flags, analytics: analytics)
    }
}
