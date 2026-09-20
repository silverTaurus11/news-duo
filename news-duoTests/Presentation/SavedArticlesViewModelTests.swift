import Testing
@testable import news_duo

@MainActor
struct SavedArticlesViewModelTests {
    private func makeViewModel(saved: [Article] = []) -> (SavedArticlesViewModel, InMemorySavedArticlesRepository) {
        let repo = InMemorySavedArticlesRepository(articles: saved)
        let viewModel = SavedArticlesViewModel(
            getSavedArticles: GetSavedArticlesUseCase(repository: repo),
            toggleSavedArticle: ToggleSavedArticleUseCase(repository: repo)
        )
        return (viewModel, repo)
    }

    @Test func loadsPersistedArticles() async {
        let (viewModel, _) = makeViewModel(saved: [.sample(1), .sample(2)])

        await viewModel.load()

        #expect(viewModel.articles.count == 2)
        #expect(viewModel.isSaved(.sample(1)))
        #expect(viewModel.isSaved(.sample(3)) == false)
    }

    @Test func toggleSavesThenUnsaves() async throws {
        let (viewModel, repo) = makeViewModel()

        await viewModel.toggle(.sample(1))
        #expect(viewModel.isSaved(.sample(1)))
        #expect(viewModel.articles == [.sample(1)])
        #expect(try await repo.loadAll() == [.sample(1)])

        await viewModel.toggle(.sample(1))
        #expect(viewModel.isSaved(.sample(1)) == false)
        #expect(viewModel.articles.isEmpty)
    }

    @Test func newestSavedIsFirst() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.toggle(.sample(1))
        await viewModel.toggle(.sample(2))

        #expect(viewModel.articles.map(\.title) == ["Headline 2", "Headline 1"])
    }

    @Test func failedToggleLeavesStateUntouchedAndReportsError() async {
        let (viewModel, repo) = makeViewModel()
        await repo.setShouldFail(true)

        await viewModel.toggle(.sample(1))

        #expect(viewModel.isSaved(.sample(1)) == false)
        #expect(viewModel.errorMessage != nil)
    }
}
