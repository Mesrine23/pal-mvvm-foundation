import Foundation

/// App-supplied configuration. The foundation ships mechanisms; the app ships values.
enum AppConfig {

    /// A public, no-auth API so the showcase runs with zero setup.
    static let baseURL: URL = {
        guard let url = URL(string: "https://jsonplaceholder.typicode.com") else {
            preconditionFailure("Invalid base URL literal")
        }
        return url
    }()
}
