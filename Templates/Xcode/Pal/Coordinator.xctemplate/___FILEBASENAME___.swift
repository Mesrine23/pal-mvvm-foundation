import SwiftUI
import PalNavigation

/// <#One-line summary of the flow this coordinator owns.#>
@MainActor
final class ___FILEBASENAME___: <#Screen#>NavigationDelegate {

    /// The router driving this feature's navigation stack.
    let router = Router<<#FeatureRoute#>>()

    private let container: <#AppContainer#>

    init(container: <#AppContainer#>) {
        self.container = container
    }

    // MARK: - <#Screen#>NavigationDelegate

    func <#showDestination#>(_ <#entity#>: <#Entity#>) {
        router.push(.<#destination#>(<#entity#>))
    }

    // MARK: - Destination factory

    /// Builds the screen for a route — compiler-enforced exhaustive switch.
    @ViewBuilder
    func view(for route: <#FeatureRoute#>) -> some View {
        switch route {
        case .<#root#>:
            <#RootScreen#>View(viewModel: container.make<#RootScreen#>ViewModel(delegate: self))
        case .<#destination#>(let <#entity#>):
            <#DestinationScreen#>View(viewModel: container.make<#DestinationScreen#>ViewModel(<#entity#>: <#entity#>))
        }
    }
}
