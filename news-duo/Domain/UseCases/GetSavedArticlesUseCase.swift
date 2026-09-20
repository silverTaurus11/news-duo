nonisolated struct GetSavedArticlesUseCase: Sendable {
    let repository: any SavedArticlesRepository

    func callAsFunction() async throws -> [Article] {
        try await repository.loadAll()
    }
}
