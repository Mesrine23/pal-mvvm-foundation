import PalNavigation

/// The app's navigation routes — payloads ride in the cases (no courier registration).
enum AppRoute: Routable {

    /// The users list (the stack's root).
    case usersList

    /// A user's detail screen.
    case userDetail(User)
}
