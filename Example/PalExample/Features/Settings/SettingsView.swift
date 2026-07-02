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
            Section("Appearance") {
                Toggle("Branded theme", isOn: $appState.useBrandedTheme)
            }
            Section("Feature flags") {
                Toggle("Show user email", isOn: $viewModel.showsUserEmail)
            }
            Section("Session") {
                if viewModel.isLoggedIn {
                    Button("Sign out", role: .destructive) {
                        Task { await viewModel.logOut() }
                    }
                } else {
                    Button("Simulate sign in") {
                        Task { await viewModel.logIn() }
                    }
                }
            }
            Section("Notifications") {
                LabeledContent("Permission", value: viewModel.notificationStatusText)
                if viewModel.notificationStatus == .notDetermined {
                    Button("Request permission") {
                        Task { await viewModel.requestNotificationPermission() }
                    }
                }
                Button("Notify now (tap the banner!)") {
                    Task { await viewModel.notifyNow() }
                }
                Button("Remind me in 5 seconds") {
                    Task { await viewModel.remindInFiveSeconds() }
                }
                Button("Register for push") {
                    viewModel.registerForPush()
                }
                if let registration = viewModel.pushRegistrationText {
                    Text(registration)
                        .font(.caption.monospaced())
                        .lineLimit(3)
                        .foregroundStyle(.secondary)
                }
            }
            Section("About") {
                LabeledContent("Version", value: viewModel.appVersion)
            }
        }
        .navigationTitle("Settings")
        .appAlert($viewModel.alert)
        .task { await viewModel.onAppear() }
        .task { await viewModel.observePushEvents() }
    }
}
