import SwiftUI

/// The showcase app entry point. Owns the composition root and shows the root view.
@main
struct PalExampleApp: App {

    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
