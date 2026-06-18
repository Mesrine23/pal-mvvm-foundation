/// Fetches the users list. One method, `execute` — the app-layer use-case convention.
nonisolated protocol FetchUsersUseCaseProtocol: Sendable {

    /// Loads the users.
    /// - Parameter forceRefresh: When `true`, bypasses the cache.
    func execute(forceRefresh: Bool) async throws -> [User]
}
