import PalCore
import PalNetworking
import PalPersistence
import os

/// Fetches users over the network with repository-level cache-aside via ``MemoryCache``.
nonisolated struct UsersRepository: UsersRepoProtocol {

    private let client: any NetworkClient
    private let cache: MemoryCache
    private let logger = LoggerFactory.make(category: "UsersRepository")

    /// Creates the repository.
    /// - Parameters:
    ///   - client: The network client.
    ///   - cache: The shared in-memory cache.
    init(client: any NetworkClient, cache: MemoryCache) {
        self.client = client
        self.cache = cache
    }

    func getUsers(forceRefresh: Bool) async throws -> [User] {
        if !forceRefresh, let cached = await cache.get(.users) {
            logger.debug("users — cache hit (\(cached.count, privacy: .public))")
            return cached
        }
        let users = try await client.send(.users()).map(\.toDomain)
        await cache.set(users, for: .users)
        return users
    }
}
