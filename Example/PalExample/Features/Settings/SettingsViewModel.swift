import Foundation
import Observation
import PalAnalytics
import PalAuth
import PalCore
import PalDesignSystem
import PalFeatureFlags
import PalNetworking

/// Drives the settings screen: a live feature-flag toggle, a demo Keychain-backed
/// session, app info, and an action-failure/confirmation alert.
@MainActor @Observable
final class SettingsViewModel {

    /// App version and build, from ``AppInfo``.
    let appVersion: String

    /// Mirrors the `showsUserEmail` flag; toggling updates the provider live.
    var showsUserEmail: Bool {
        didSet { flags.set(showsUserEmail, forKey: FeatureFlag.showsUserEmail.key) }
    }

    /// Whether a demo session token is stored in the Keychain.
    var isLoggedIn = false

    /// The action-failure / confirmation channel.
    var alert: AppAlert?

    @ObservationIgnored private let tokenStore: KeychainTokenStore
    @ObservationIgnored private let flags: InMemoryFeatureFlagsProvider
    @ObservationIgnored private let analytics: any AnalyticsTracker

    /// Creates the ViewModel.
    init(
        tokenStore: KeychainTokenStore,
        flags: InMemoryFeatureFlagsProvider,
        analytics: any AnalyticsTracker
    ) {
        self.tokenStore = tokenStore
        self.flags = flags
        self.analytics = analytics
        self.appVersion = "\(AppInfo.current.version) (\(AppInfo.current.build))"
        self.showsUserEmail = flags.isEnabled(.showsUserEmail)
    }

    /// Loads session state and tracks the screen view.
    func onAppear() async {
        analytics.track(.screenViewed("settings"))
        let tokens = await tokenStore.tokens()
        isLoggedIn = tokens != nil
    }

    /// Saves a demo token to the Keychain (dogfoods PalAuth + Keychain).
    func logIn() async {
        await tokenStore.save(AuthTokens(accessToken: "demo-access", refreshToken: "demo-refresh"))
        isLoggedIn = true
        analytics.track(.loggedIn)
        alert = AppAlert(
            kind: .success,
            title: String(localized: "Signed in"),
            message: String(localized: "A demo token was saved to the Keychain."),
            primary: AlertAction(String(localized: "OK"))
        )
    }

    /// Clears the demo token.
    func logOut() async {
        await tokenStore.clear()
        isLoggedIn = false
        analytics.track(.loggedOut)
    }
}
