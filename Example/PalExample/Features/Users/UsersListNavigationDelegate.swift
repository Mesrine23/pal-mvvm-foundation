/// Navigation intents the users-list screen delegates to its coordinator.
@MainActor
protocol UsersListNavigationDelegate: AnyObject {

    /// Show the detail screen for the given user.
    func showUserDetail(_ user: User)
}
