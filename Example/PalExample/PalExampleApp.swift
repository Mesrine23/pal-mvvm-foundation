import SwiftUI

/// The showcase app entry point. Owns the composition root and shows the root view.
@main
struct PalExampleApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var container = AppContainer()

    init() {
        appDelegate.notifications = container.notifications
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
