import Foundation

/// App-supplied configuration. The foundation ships mechanisms; the app ships values.
/// `nonisolated`: pure constants consumed by nonisolated code (the client's
/// `@Sendable` base-URL provider) under MainActor-default isolation.
nonisolated enum AppConfig {

    /// A public, no-auth API so the showcase runs with zero setup.
    static let baseURL: URL = {
        guard let url = URL(string: "https://jsonplaceholder.typicode.com") else {
            preconditionFailure("Invalid base URL literal")
        }
        return url
    }()

    /// A second environment for the DebugKit API switcher demo (won't resolve —
    /// switching to it shows the error state, proving the switch took effect).
    static let localhostURL: URL = {
        guard let url = URL(string: "http://localhost:3000") else {
            preconditionFailure("Invalid base URL literal")
        }
        return url
    }()

    /// The Pal repository — the About screen's embedded page.
    static let repositoryURL: URL = {
        guard let url = URL(string: "https://github.com/Mesrine23/pal-mvvm-foundation") else {
            preconditionFailure("Invalid repository URL literal")
        }
        return url
    }()
}
