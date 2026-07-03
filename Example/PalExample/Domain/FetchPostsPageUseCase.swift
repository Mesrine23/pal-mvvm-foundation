/// Fetches one page of posts.
nonisolated protocol FetchPostsPageUseCaseProtocol: Sendable {
    func execute(page: Int) async throws -> PostsPage
}

nonisolated struct FetchPostsPageUseCase: FetchPostsPageUseCaseProtocol {

    private let postsRepo: PostsRepoProtocol

    init(postsRepo: PostsRepoProtocol) {
        self.postsRepo = postsRepo
    }

    func execute(page: Int) async throws -> PostsPage {
        try await postsRepo.getPosts(page: page)
    }
}
