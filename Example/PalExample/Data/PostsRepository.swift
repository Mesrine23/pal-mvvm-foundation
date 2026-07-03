import PalNetworking

/// Fetches post pages from the API; derives `hasMore` from the page size
/// (a short page means the end was reached).
nonisolated struct PostsRepository: PostsRepoProtocol {

    private static let pageSize = 20

    private let client: any NetworkClient

    init(client: any NetworkClient) {
        self.client = client
    }

    func getPosts(page: Int) async throws -> PostsPage {
        let dtos = try await client.send(.posts(page: page, limit: Self.pageSize))
        return PostsPage(posts: dtos.map(\.toDomain), hasMore: dtos.count == Self.pageSize)
    }
}
