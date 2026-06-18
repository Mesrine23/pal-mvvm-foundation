/// The production ``FetchUsersUseCaseProtocol`` — delegates to the repository.
nonisolated struct FetchUsersUseCase: FetchUsersUseCaseProtocol {

    private let usersRepo: any UsersRepoProtocol

    /// Creates the use case.
    /// - Parameter usersRepo: The repository providing user data.
    init(usersRepo: any UsersRepoProtocol) {
        self.usersRepo = usersRepo
    }

    func execute(forceRefresh: Bool) async throws -> [User] {
        try await usersRepo.getUsers(forceRefresh: forceRefresh)
    }
}
