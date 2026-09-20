import Foundation
import Testing
@testable import news_duo

@MainActor
struct NewsFeedViewModelTests {
    private static let usHeadlines = ArticleQuery.topHeadlines(country: .unitedStates, category: nil)

    private func makeViewModel(_ results: [Result<ArticlesPage, NewsError>]) -> (NewsFeedViewModel, FakeNewsRepository) {
        let repo = FakeNewsRepository(results: results)
        let viewModel = NewsFeedViewModel(fetchArticles: FetchArticlesUseCase(repository: repo), pageSize: 2)
        return (viewModel, repo)
    }

    private func page(_ numbers: [Int], hasMore: Bool = false) -> Result<ArticlesPage, NewsError> {
        .success(ArticlesPage(articles: numbers.map(Article.sample), hasMore: hasMore))
    }

    // MARK: - Loading & paging

    @Test func loadsTopHeadlinesForTheDefaultCountry() async {
        let (viewModel, repo) = makeViewModel([page([1, 2], hasMore: true)])

        await viewModel.loadIfNeeded()

        #expect(viewModel.phase == .content)
        #expect(viewModel.articles.map(\.title) == ["Headline 1", "Headline 2"])
        #expect(viewModel.canLoadMore)
        #expect(await repo.requestedQueries == [Self.usHeadlines])
    }

    @Test func loadIfNeededOnlyLoadsOnce() async {
        let (viewModel, repo) = makeViewModel([page([1]), page([9])])

        await viewModel.loadIfNeeded()
        await viewModel.loadIfNeeded()

        #expect(await repo.requestedPages == [1])
    }

    @Test func initialFailureShowsErrorAndRetryRecovers() async {
        let (viewModel, _) = makeViewModel([.failure(.offline), page([1])])

        await viewModel.loadIfNeeded()
        #expect(viewModel.phase == .failed(NewsError.offline.localizedDescription))

        await viewModel.reload()
        #expect(viewModel.phase == .content)
        #expect(viewModel.articles.count == 1)
    }

    @Test func loadsNextPageWhenLastRowAppears() async {
        let (viewModel, repo) = makeViewModel([page([1, 2], hasMore: true), page([3])])
        await viewModel.loadIfNeeded()

        await viewModel.loadMoreIfNeeded(after: .sample(1))
        #expect(viewModel.articles.count == 2)

        await viewModel.loadMoreIfNeeded(after: .sample(2))
        #expect(viewModel.articles.map(\.title) == ["Headline 1", "Headline 2", "Headline 3"])
        #expect(viewModel.canLoadMore == false)
        #expect(await repo.requestedPages == [1, 2])
    }

    @Test func dropsDuplicateArticlesAcrossPages() async {
        let (viewModel, _) = makeViewModel([page([1, 2], hasMore: true), page([2, 3])])
        await viewModel.loadIfNeeded()

        await viewModel.loadMore()

        #expect(viewModel.articles.map(\.title) == ["Headline 1", "Headline 2", "Headline 3"])
    }

    @Test func loadMoreFailureShowsTheReasonAndIsRetryable() async {
        let (viewModel, _) = makeViewModel([page([1, 2], hasMore: true), .failure(.offline), page([3], hasMore: true)])
        await viewModel.loadIfNeeded()

        await viewModel.loadMore()
        #expect(viewModel.footerState == .failed(NewsError.offline.localizedDescription))
        #expect(viewModel.articles.count == 2, "already loaded articles stay on screen")

        await viewModel.loadMore()
        #expect(viewModel.footerState == .hidden)
        #expect(viewModel.articles.count == 3)
    }

    @Test func aFailedLoadMoreIsNotRetriedByScrollingAgain() async {
        let (viewModel, repo) = makeViewModel([page([1, 2], hasMore: true), .failure(.offline), page([3])])
        await viewModel.loadIfNeeded()
        await viewModel.loadMoreIfNeeded(after: .sample(2))

        await viewModel.loadMoreIfNeeded(after: .sample(2))

        #expect(await repo.requestedPages == [1, 2], "only the explicit retry button asks again")
    }

    @Test func maximumResultsEndsTheListWithThePlanLimitMessage() async {
        let (viewModel, _) = makeViewModel([page([1, 2], hasMore: true), .failure(.maximumResultsReached)])
        await viewModel.loadIfNeeded()

        await viewModel.loadMore()

        #expect(viewModel.canLoadMore == false)
        #expect(viewModel.footerState == .endOfList(NewsError.maximumResultsReached.localizedDescription))
    }

    // MARK: - Page size & footer

    @Test func defaultPageSizeIsTen() async {
        let repo = FakeNewsRepository(results: [page([1], hasMore: true), page([2])])
        let viewModel = NewsFeedViewModel(fetchArticles: FetchArticlesUseCase(repository: repo))

        await viewModel.loadIfNeeded()
        await viewModel.loadMore()

        #expect(NewsFeedViewModel.defaultPageSize == 10)
        #expect(await repo.requests.map(\.pageSize) == [10, 10])
    }

    @Test func footerIsHiddenWhileMorePagesAreAvailable() async {
        let (viewModel, _) = makeViewModel([page([1, 2], hasMore: true)])
        #expect(viewModel.footerState == .hidden, "nothing loaded yet")

        await viewModel.loadIfNeeded()

        #expect(viewModel.footerState == .hidden)
    }

    @Test func footerSaysYoureCaughtUpAfterTheLastPage() async {
        let (viewModel, _) = makeViewModel([page([1, 2], hasMore: true), page([3])])
        await viewModel.loadIfNeeded()

        await viewModel.loadMore()

        #expect(viewModel.footerState == .endOfList("You're all caught up."))
    }

    @Test func footerStaysHiddenWhenThereAreNoArticlesAtAll() async {
        let (viewModel, _) = makeViewModel([page([])])

        await viewModel.loadIfNeeded()

        #expect(viewModel.footerState == .hidden, "the empty state covers this case")
    }

    @Test func footerShowsLoadingWhileTheNextPageIsInFlight() async {
        let repo = KeyedNewsRepository(responses: [
            Self.usHeadlines: .init(delay: .milliseconds(200), page: ArticlesPage(articles: [.sample(1)], hasMore: true)),
        ])
        let viewModel = NewsFeedViewModel(fetchArticles: FetchArticlesUseCase(repository: repo), pageSize: 2)
        await viewModel.loadIfNeeded()

        let next = Task { await viewModel.loadMore() }
        while await repo.requestCount < 2 { await Task.yield() }
        #expect(viewModel.footerState == .loading)

        await next.value
        #expect(viewModel.footerState == .hidden)
    }

    @Test func changingTheFilterClearsALoadMoreError() async {
        let (viewModel, _) = makeViewModel([page([1, 2], hasMore: true), .failure(.offline), page([3], hasMore: true)])
        await viewModel.loadIfNeeded()
        await viewModel.loadMore()
        #expect(viewModel.footerState == .failed(NewsError.offline.localizedDescription))

        await viewModel.select(category: .sports)

        #expect(viewModel.footerState == .hidden)
    }

    @Test func refreshFailureKeepsExistingContentAndRaisesAlert() async {
        let (viewModel, _) = makeViewModel([page([1, 2]), .failure(.rateLimited)])
        await viewModel.loadIfNeeded()

        await viewModel.reload()

        #expect(viewModel.phase == .content)
        #expect(viewModel.articles.count == 2)
        #expect(viewModel.alertMessage == NewsError.rateLimited.localizedDescription)
    }

    @Test func emptyFirstPageThatHasMoreStillAllowsLoadingMore() async {
        // NewsAPI sorted by popularity can return an empty page while more exist.
        let (viewModel, _) = makeViewModel([page([], hasMore: true), page([1])])
        await viewModel.loadIfNeeded()
        #expect(viewModel.phase == .content)
        #expect(viewModel.articles.isEmpty)
        #expect(viewModel.canLoadMore)

        await viewModel.loadMore()
        #expect(viewModel.articles.count == 1)
    }

    // MARK: - Top headlines filters

    @Test func selectingACountryReloadsWithThatCountry() async {
        let (viewModel, repo) = makeViewModel([page([1, 2]), page([3])])
        await viewModel.loadIfNeeded()

        await viewModel.select(country: Country(code: "gb"))

        #expect(viewModel.country == Country(code: "gb"))
        #expect(viewModel.articles.map(\.title) == ["Headline 3"])
        #expect(await repo.requestedQueries == [
            Self.usHeadlines,
            .topHeadlines(country: Country(code: "gb"), category: nil),
        ])
    }

    @Test func selectingACategoryAndThenAllReloadsEachTime() async {
        let (viewModel, repo) = makeViewModel([page([1]), page([2]), page([3])])
        await viewModel.loadIfNeeded()

        await viewModel.select(category: .sports)
        await viewModel.select(category: nil)

        #expect(await repo.requestedQueries == [
            Self.usHeadlines,
            .topHeadlines(country: .unitedStates, category: .sports),
            Self.usHeadlines,
        ])
    }

    @Test func reselectingTheSameFilterDoesNotReload() async {
        let (viewModel, repo) = makeViewModel([page([1]), page([2])])
        await viewModel.loadIfNeeded()

        await viewModel.select(country: .unitedStates)
        await viewModel.select(category: nil)

        #expect(await repo.requestedPages == [1])
    }

    @Test func changingFilterClearsOldArticlesAndPaging() async {
        let (viewModel, repo) = makeViewModel([page([1, 2], hasMore: true), page([3])])
        await viewModel.loadIfNeeded()

        await viewModel.select(category: .health)

        #expect(viewModel.articles.map(\.title) == ["Headline 3"])
        #expect(viewModel.canLoadMore == false)
        #expect(await repo.requestedPages == [1, 1])
    }

    // MARK: - Search

    @Test func submittingASearchSwitchesToEverythingWithTheSortOrder() async {
        let (viewModel, repo) = makeViewModel([page([1]), page([2])])
        await viewModel.loadIfNeeded()

        viewModel.searchText = "iphone duo"
        await viewModel.applySearch()

        #expect(viewModel.isSearching)
        #expect(viewModel.activeSearchTerm == "iphone duo")
        #expect(await repo.requestedQueries.last == .search(term: "iphone duo", sortOrder: .relevancy))
    }

    @Test func searchTermIsTrimmedAndCapped() async {
        let (viewModel, _) = makeViewModel([page([1]), page([2]), page([3])])

        viewModel.searchText = "   apple  \n"
        await viewModel.applySearch()
        #expect(viewModel.activeSearchTerm == "apple")

        viewModel.searchText = String(repeating: "a", count: 600)
        await viewModel.applySearch()
        #expect(viewModel.activeSearchTerm?.count == 500)
    }

    @Test func blankSearchLeavesSearchModeAndReturnsToHeadlines() async {
        let (viewModel, repo) = makeViewModel([page([1]), page([2]), page([3])])
        await viewModel.loadIfNeeded()
        viewModel.searchText = "apple"
        await viewModel.applySearch()

        viewModel.searchText = ""
        await viewModel.applySearch()

        #expect(viewModel.isSearching == false)
        #expect(await repo.requestedQueries.last == Self.usHeadlines)
    }

    @Test func submittingBlankTextWhileNotSearchingDoesNothing() async {
        let (viewModel, repo) = makeViewModel([page([1]), page([2])])
        await viewModel.loadIfNeeded()

        viewModel.searchText = "   "
        await viewModel.applySearch()

        #expect(await repo.requestedPages == [1])
    }

    @Test func resubmittingTheSameSearchDoesNotSpendAnotherRequest() async {
        let (viewModel, repo) = makeViewModel([page([1]), page([2])])
        viewModel.searchText = "apple"

        await viewModel.applySearch()
        await viewModel.applySearch()

        #expect(await repo.requestedPages == [1])
    }

    @Test func sortOrderReloadsOnlyWhileSearching() async {
        let (viewModel, repo) = makeViewModel([page([1]), page([2]), page([3])])
        await viewModel.loadIfNeeded()

        await viewModel.select(sortOrder: .popularity)
        #expect(await repo.requestedPages == [1], "not searching, so sort order isn't part of the query")

        viewModel.searchText = "apple"
        await viewModel.applySearch()
        #expect(await repo.requestedQueries.last == .search(term: "apple", sortOrder: .popularity))

        await viewModel.select(sortOrder: .newest)
        #expect(await repo.requestedQueries.last == .search(term: "apple", sortOrder: .newest))
    }

    // MARK: - Stale responses

    @Test func aSlowResponseToAnOlderQueryIsIgnored() async {
        let sports = ArticleQuery.topHeadlines(country: .unitedStates, category: .sports)
        let health = ArticleQuery.topHeadlines(country: .unitedStates, category: .health)
        let repo = KeyedNewsRepository(responses: [
            Self.usHeadlines: .init(delay: .zero, page: ArticlesPage(articles: [.sample(1)], hasMore: false)),
            sports: .init(delay: .milliseconds(300), page: ArticlesPage(articles: [.sample(2)], hasMore: false)),
            health: .init(delay: .zero, page: ArticlesPage(articles: [.sample(3)], hasMore: false)),
        ])
        let viewModel = NewsFeedViewModel(fetchArticles: FetchArticlesUseCase(repository: repo), pageSize: 2)
        await viewModel.loadIfNeeded()

        // Start the slow request, wait until it is really in flight, then supersede it.
        let slow = Task { await viewModel.select(category: .sports) }
        while await repo.requestCount < 2 { await Task.yield() }
        await viewModel.select(category: .health)
        await slow.value

        #expect(viewModel.category == .health)
        #expect(viewModel.articles.map(\.title) == ["Headline 3"])
        #expect(viewModel.phase == .content)
    }
}
