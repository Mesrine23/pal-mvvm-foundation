import SwiftUI
import PalDesignSystem
import PalNavigation
import PalNotifications
import PalDebugKit

/// The root tab view: a navigated Users tab (driven by a ``Router``) and a Settings
/// tab. Applies the theme, and routes notification taps into the coordinator.
struct RootView: View {

    private let container: AppContainer
    @State private var coordinator: AppCoordinator
    @State private var selectedTab: AppTab = .users
    @State private var environmentToken = 0

    init(container: AppContainer) {
        self.container = container
        _coordinator = State(initialValue: AppCoordinator(container: container))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Users", systemImage: "person.2", value: .users) {
                RouterView(router: coordinator.router, root: .usersList) { route in
                    coordinator.view(for: route)
                }
                .id(environmentToken)
            }
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                NavigationStack {
                    SettingsView(
                        viewModel: container.makeSettingsViewModel(),
                        appState: container.appState
                    )
                }
            }
        }
        .theme(container.appState.useBrandedTheme ? .showcase : .system)
        .task {
            for await response in container.notifications.responses {
                selectedTab = .users
                coordinator.handleNotification(response)
            }
        }
        #if DEBUGKIT
        .onShake { PalDebugTools.shared.present() }
        .task {
            for await _ in PalDebugTools.shared.environmentChanges {
                environmentToken += 1
            }
        }
        #endif
    }
}

private enum AppTab {
    case users
    case settings
}
