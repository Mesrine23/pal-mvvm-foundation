import PalPersistence

/// UserDefaults keys owned by the app (no keys ship in the foundation).
extension DefaultsKey where Value == Bool {

    /// Whether the lightly branded theme is active.
    static var useBrandedTheme: DefaultsKey<Bool> {
        DefaultsKey("useBrandedTheme", default: false)
    }
}

extension DefaultsKey where Value == [Int] {

    /// The IDs of users the person has favorited.
    static var favoriteUserIDs: DefaultsKey<[Int]> {
        DefaultsKey("favoriteUserIDs", default: [])
    }
}
