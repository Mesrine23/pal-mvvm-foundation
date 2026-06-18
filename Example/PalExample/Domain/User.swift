/// A user in the showcase domain — a pure value type.
///
/// Marked `nonisolated` because this app target defaults to main-actor isolation
/// (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`); the entity must be constructible
/// off the main actor inside the repository's async work and `Loader`'s operation.
nonisolated struct User: Identifiable, Hashable, Sendable {

    /// The user's stable identifier.
    let id: Int

    /// The user's display name.
    let name: String

    /// The user's email address.
    let email: String

    /// The user's company name.
    let company: String
}
