import Testing
@testable import news_duo

struct ToggleSavedArticleUseCaseTests {
    @Test func savesAnArticleThatIsNotSaved() async throws {
        let repo = InMemorySavedArticlesRepository()
        let toggle = ToggleSavedArticleUseCase(repository: repo)

        let isSaved = try await toggle(.sample(1))

        #expect(isSaved)
        #expect(try await repo.loadAll() == [.sample(1)])
    }

    @Test func removesAnArticleThatIsAlreadySaved() async throws {
        let repo = InMemorySavedArticlesRepository(articles: [.sample(1)])
        let toggle = ToggleSavedArticleUseCase(repository: repo)

        let isSaved = try await toggle(.sample(1))

        #expect(isSaved == false)
        #expect(try await repo.loadAll().isEmpty)
    }

    @Test func propagatesRepositoryFailures() async {
        let repo = InMemorySavedArticlesRepository()
        await repo.setShouldFail(true)

        await #expect(throws: NewsError.invalidResponse) {
            try await ToggleSavedArticleUseCase(repository: repo)(.sample(1))
        }
    }
}
