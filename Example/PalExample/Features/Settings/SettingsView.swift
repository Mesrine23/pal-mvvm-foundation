import SwiftUI
import PalDesignSystem
import PalNotifications

/// The settings tab — theming, feature flags, a demo session, and app info.
struct SettingsView: View {

    @State private var viewModel: SettingsViewModel
    private let appState: AppState

    init(viewModel: SettingsViewModel, appState: AppState) {
        _viewModel = State(initialValue: viewModel)
        self.appState = appState
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        @Bindable var appState = appState

        Form {
            Section(.settingsSectionAppearance) {
                Toggle(.settingsBrandedTheme, isOn: $appState.useBrandedTheme)
            }
            Section(.settingsSectionFeatureFlags) {
                Toggle(.settingsShowUserEmail, isOn: $viewModel.showsUserEmail)
            }
            Section(.settingsSectionSession) {
                if viewModel.isLoggedIn {
                    Button(.settingsSignOut, role: .destructive) {
                        Task { await viewModel.logOut() }
                    }
                } else {
                    Button(.settingsSimulateSignIn) {
                        Task { await viewModel.logIn() }
                    }
                }
            }
            Section(.settingsSectionNotifications) {
                LabeledContent(.settingsPermission, value: viewModel.notificationStatusText)
                if viewModel.notificationStatus == .notDetermined {
                    Button(.settingsRequestPermission) {
                        Task { await viewModel.requestNotificationPermission() }
                    }
                }
                Button(.settingsNotifyNow) {
                    Task { await viewModel.notifyNow() }
                }
                Button(.settingsRemindLater) {
                    Task { await viewModel.remindInFiveSeconds() }
                }
                Button(.settingsRegisterForPush) {
                    viewModel.registerForPush()
                }
                if let registration = viewModel.pushRegistrationText {
                    Text(registration)
                        .font(.caption.monospaced())
                        .lineLimit(3)
                        .foregroundStyle(.secondary)
                }
            }
            Section(.settingsSectionAbout) {
                LabeledContent(.settingsVersion, value: viewModel.appVersion)
                NavigationLink(.aboutPalTitle) { AboutPalView() }
                Button(.settingsGitHub) { viewModel.openRepository() }
            }
        }
        .navigationTitle(.settingsTitle)
        .appAlert($viewModel.alert)
        .appToast($viewModel.toast)
        .task { await viewModel.onAppear() }
        .task { await viewModel.observePushEvents() }
    }
}
