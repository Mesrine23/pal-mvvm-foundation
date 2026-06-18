import PalFeatureFlags

/// The app's feature flags, declared as static factories with safe defaults.
extension FeatureFlag {

    /// When on, the user detail screen shows the email address.
    static var showsUserEmail: FeatureFlag {
        FeatureFlag(key: "shows_user_email", defaultValue: true)
    }
}
