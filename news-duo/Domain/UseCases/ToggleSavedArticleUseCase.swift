nonisolated struct ToggleSavedArticleUseCase: Sendable {
    let repository: any SavedArticlesRepository

    /// Saves the article if it isn't saved, removes it otherwise.
    /// - Returns: `true` if the article is saved after the call.
    func callAsFunction(_ article: Article) async throws -> Bool {
        if try await repository.contains(id: article.id) {
            try await repository.remove(id: article.id)
            return false
        }
        try await repository.save(article)
        return true
    }
}
