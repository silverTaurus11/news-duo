nonisolated protocol NewsRepository: Sendable {
    /// Pages are 1-based.
    func articles(for query: ArticleQuery, page: Int, pageSize: Int) async throws -> ArticlesPage
}
