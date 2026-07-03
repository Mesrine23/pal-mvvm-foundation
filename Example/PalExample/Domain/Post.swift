/// A post in the showcase domain — a pure value type.
///
/// `nonisolated` for the same reason as ``User``: the app target defaults to
/// main-actor isolation, and entities must construct off-actor.
nonisolated struct Post: Identifiable, Hashable, Sendable {

    /// The post's stable identifier.
    let id: Int

    /// The post title.
    let title: String

    /// The post body text.
    let body: String
}
