/// Wire model for the public `/users` endpoint; maps to the ``User`` entity.
///
/// `nonisolated` so its synthesized `Decodable` init satisfies the nonisolated
/// protocol requirement and decodes off the main actor inside `PalNetworking`.
nonisolated struct UserDTO: Decodable, Sendable {

    let id: Int
    let name: String
    let email: String
    let company: Company

    /// The nested company object returned by the API.
    nonisolated struct Company: Decodable, Sendable {
        let name: String
    }

    /// Maps the wire model to the domain entity.
    var toDomain: User {
        User(id: id, name: name, email: email, company: company.name)
    }
}
