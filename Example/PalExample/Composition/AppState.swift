import Observation
import PalPersistence

/// App-wide UI state shared across the tabs — here, the theme-branding toggle,
/// persisted via ``UserDefaultsService``.
@MainActor @Observable
final class AppState {

    /// Whether the lightly branded theme is active.
    var useBrandedTheme: Bool {
        didSet { defaults.set(useBrandedTheme, for: .useBrandedTheme) }
    }

    @ObservationIgnored private let defaults: UserDefaultsService

    /// Creates app state, seeding the toggle from persisted defaults.
    init(defaults: UserDefaultsService) {
        self.defaults = defaults
        self.useBrandedTheme = defaults.get(.useBrandedTheme) ?? false
    }
}
