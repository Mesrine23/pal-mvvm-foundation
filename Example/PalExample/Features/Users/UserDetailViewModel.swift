import Observation
import PalAnalytics
import PalFeatureFlags
import PalPersistence

/// Drives the user detail screen: a favorite toggle persisted via UserDefaults,
/// with email visibility gated by a feature flag.
@MainActor @Observable
final class UserDetailViewModel {

    /// The user being shown.
    let user: User

    /// Whether the email row is shown (feature-flag driven).
    let showsEmail: Bool

    /// Whether this user is favorited.
    var isFavorite: Bool

    @ObservationIgnored private let defaults: UserDefaultsService
    @ObservationIgnored private let analytics: any AnalyticsTracker

    /// Creates the ViewModel.
    init(
        user: User,
        defaults: UserDefaultsService,
        flags: any FeatureFlagsProvider,
        analytics: any AnalyticsTracker
    ) {
        self.user = user
        self.defaults = defaults
        self.analytics = analytics
        self.showsEmail = flags.isEnabled(.showsUserEmail)
        self.isFavorite = (defaults.get(.favoriteUserIDs) ?? []).contains(user.id)
    }

    /// Tracks the screen view.
    func onAppear() {
        analytics.track(.screenViewed("user_detail"))
    }

    /// Adds or removes this user from the persisted favorites.
    func toggleFavorite() {
        var ids = defaults.get(.favoriteUserIDs) ?? []
        if isFavorite {
            ids.removeAll { $0 == user.id }
        } else {
            ids.append(user.id)
        }
        defaults.set(ids, for: .favoriteUserIDs)
        isFavorite.toggle()
        analytics.track(.favoriteToggled(on: isFavorite))
    }
}
