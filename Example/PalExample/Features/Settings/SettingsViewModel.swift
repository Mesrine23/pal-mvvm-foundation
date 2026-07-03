import Foundation
import Observation
import PalAnalytics
import PalAuth
import PalCore
import PalDesignSystem
import PalFeatureFlags
import PalNetworking
import PalNotifications
import PalPresentation
import PalWeb

/// Drives the settings screen: a live feature-flag toggle, a demo Keychain-backed
/// session, the notifications demo (permission, local scheduling, APNs), app info,
/// and an action-failure/confirmation alert.
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

    /// The current notification permission.
    var notificationStatus: NotificationAuthorizationStatus = .notDetermined

    /// The APNs token hex (or the registration failure message).
    var pushRegistrationText: String?

    /// The action-failure / confirmation channel.
    var alert: AppAlert?

    /// The non-blocking confirmation channel.
    var toast: AppToast?

    @ObservationIgnored private let tokenStore: KeychainTokenStore
    @ObservationIgnored private let flags: InMemoryFeatureFlagsProvider
    @ObservationIgnored private let analytics: any AnalyticsTracker
    @ObservationIgnored private let notifications: NotificationService
    @ObservationIgnored private let linkOpener: ExternalLinkOpener

    /// Creates the ViewModel.
    init(
        tokenStore: KeychainTokenStore,
        flags: InMemoryFeatureFlagsProvider,
        analytics: any AnalyticsTracker,
        notifications: NotificationService,
        linkOpener: ExternalLinkOpener
    ) {
        self.tokenStore = tokenStore
        self.flags = flags
        self.analytics = analytics
        self.notifications = notifications
        self.linkOpener = linkOpener
        self.appVersion = "\(AppInfo.current.version) (\(AppInfo.current.build))"
        self.showsUserEmail = flags.isEnabled(.showsUserEmail)
    }

    /// Loads session + permission state and tracks the screen view.
    func onAppear() async {
        analytics.track(.screenViewed("settings"))
        let tokens = await tokenStore.tokens()
        isLoggedIn = tokens != nil
        notificationStatus = await notifications.authorizationStatus()
    }

    // MARK: - Notifications demo

    /// The permission state as display text.
    var notificationStatusText: String {
        switch notificationStatus {
        case .notDetermined: String(localized: "Not asked")
        case .denied: String(localized: "Denied")
        case .authorized: String(localized: "Authorized")
        case .provisional: String(localized: "Provisional")
        case .ephemeral: String(localized: "Ephemeral")
        }
    }

    /// Prompts for notification permission and refreshes the status row.
    func requestNotificationPermission() async {
        do {
            _ = try await notifications.requestAuthorization()
        } catch {
            alert = .error(PresentableError(from: error))
        }
        notificationStatus = await notifications.authorizationStatus()
    }

    /// Fires a client-side notification NOW (the action-triggered path);
    /// the foreground policy shows it as a banner even while the app is open.
    func notifyNow() async {
        do {
            try await notifications.schedule(.demoSpotlight)
            analytics.track(.notificationScheduled("demo-spotlight"))
            toast = AppToast(kind: .success, title: String(localized: "Notification sent"))
        } catch {
            alert = .error(PresentableError(from: error))
        }
    }

    /// Schedules a local notification 5 seconds out — background the app to see it.
    func remindInFiveSeconds() async {
        do {
            try await notifications.schedule(.demoReminder, trigger: .after(.seconds(5)))
            analytics.track(.notificationScheduled("demo-reminder"))
            toast = AppToast(
                kind: .success,
                title: String(localized: "Reminder scheduled"),
                message: String(localized: "Background the app to see it arrive.")
            )
        } catch {
            alert = .error(PresentableError(from: error))
        }
    }

    /// Opens the Pal repository in the external browser (the non-View opener).
    func openRepository() {
        analytics.track(.screenViewed("repository-external"))
        linkOpener.open(AppConfig.repositoryURL)
    }

    /// Kicks off APNs registration; the outcome lands in ``pushRegistrationText``.
    func registerForPush() {
        notifications.registerForRemoteNotifications()
    }

    /// Long-running observation of APNs registration outcomes (drive from `.task`).
    func observePushEvents() async {
        for await event in notifications.pushEvents {
            switch event {
            case .registered(let token):
                pushRegistrationText = token.hexString
            case .failed(let message):
                pushRegistrationText = message
            }
        }
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
