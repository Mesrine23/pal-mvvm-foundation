import PalPersistence

/// Cache keys owned by the app (no keys ship in the foundation).
extension CacheKey where Value == [User] {

    /// Caches the users list for two minutes (passive TTL, memory-only).
    static var users: CacheKey<[User]> {
        CacheKey("users", ttl: .seconds(120))
    }
}
