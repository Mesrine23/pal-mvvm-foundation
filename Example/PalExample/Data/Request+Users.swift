import PalNetworking

/// Endpoint factories for the users API — defined in the Data layer per the convention.
extension Request {

    /// `GET /users` → the full users list.
    static func users() -> Request<[UserDTO]> {
        Request<[UserDTO]>(path: "/users")
    }
}
