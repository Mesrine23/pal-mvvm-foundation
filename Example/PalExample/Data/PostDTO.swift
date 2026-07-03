/// The wire shape of a post; mapped to the domain entity in the repository.
nonisolated struct PostDTO: Decodable, Sendable {

    let id: Int
    let title: String
    let body: String

    var toDomain: Post {
        Post(id: id, title: title, body: body)
    }
}
