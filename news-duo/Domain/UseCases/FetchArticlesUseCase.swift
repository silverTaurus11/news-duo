nonisolated struct FetchArticlesUseCase: Sendable {
    let repository: any NewsRepository

    func callAsFunction(_ query: ArticleQuery, page: Int, pageSize: Int) async throws -> ArticlesPage {
        try await repository.articles(for: query, page: page, pageSize: pageSize)
    }
}
