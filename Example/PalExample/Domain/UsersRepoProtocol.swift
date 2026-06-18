/// The seam the domain depends on for user data — implemented in the Data layer.
nonisolated protocol UsersRepoProtocol: Sendable {

    /// Returns the users, optionally bypassing any cache.
    /// - Parameter forceRefresh: When `true`, skips the cache and fetches fresh.
    func getUsers(forceRefresh: Bool) async throws -> [User]
}
