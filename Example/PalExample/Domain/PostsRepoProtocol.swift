/// One fetched page of posts, with the has-more signal the data source derives.
nonisolated struct PostsPage: Sendable, Equatable {

    /// The posts of this page, in display order.
    let posts: [Post]

    /// Whether another page exists after this one.
    let hasMore: Bool
}

/// The posts data seam — paged reads.
nonisolated protocol PostsRepoProtocol: Sendable {

    /// Returns one page of posts (1-based page index).
    func getPosts(page: Int) async throws -> PostsPage
}
