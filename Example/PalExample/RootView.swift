import SwiftUI
import PalDesignSystem
import PalNavigation

/// The root tab view: a navigated Users tab (driven by a ``Router``) and a Settings
/// tab. Applies the theme based on app state.
struct RootView: View {

    private let container: AppContainer
    @State private var coordinator: AppCoordinator

    init(container: AppContainer) {
        self.container = container
        _coordinator = State(initialValue: AppCoordinator(container: container))
    }

    var body: some View {
        TabView {
            Tab("Users", systemImage: "person.2") {
                RouterView(router: coordinator.router, root: .usersList) { route in
                    coordinator.view(for: route)
                }
            }
            Tab("Settings", systemImage: "gearshape") {
                NavigationStack {
                    SettingsView(
                        viewModel: container.makeSettingsViewModel(),
                        appState: container.appState
                    )
                }
            }
        }
        .theme(container.appState.useBrandedTheme ? .showcase : .system)
    }
}
