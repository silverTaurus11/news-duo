nonisolated protocol SavedArticlesRepository: Sendable {
    /// Saved articles, most recently saved first.
    func loadAll() async throws -> [Article]
    func contains(id: Article.ID) async throws -> Bool
    func save(_ article: Article) async throws
    func remove(id: Article.ID) async throws
}
