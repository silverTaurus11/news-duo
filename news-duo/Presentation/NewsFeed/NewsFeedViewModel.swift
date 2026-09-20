import Foundation
import Observation

/// Drives the news list. Without a search term it shows top headlines for the
/// selected country and category; once a search is submitted it shows search
/// results for the selected sort order.
@Observable
final class NewsFeedViewModel {
    enum Phase: Equatable {
        case idle
        case loading
        case content
        case failed(String)
    }

    private(set) var articles: [Article] = []
    private(set) var phase: Phase = .idle
    private(set) var isLoadingMore = false
    /// Why the last "load more" failed; `nil` when it hasn't.
    private(set) var loadMoreError: String?
    private(set) var canLoadMore = false
    private var endOfListMessage = NewsFeedViewModel.defaultEndOfListMessage
    /// Set when a refresh fails while older content is still on screen.
    var alertMessage: String?

    private(set) var country: Country
    private(set) var category: NewsCategory?
    private(set) var sortOrder: ArticleSortOrder = .relevancy
    /// Text in the search field. It only becomes a search once submitted, which
    /// keeps typing from spending API requests.
    var searchText = ""
    private(set) var activeSearchTerm: String?

    var isSearching: Bool { activeSearchTerm != nil }

    /// What the row after the last article should show while paging.
    enum FooterState: Equatable {
        case hidden
        case loading
        case failed(String)
        case endOfList(String)
    }

    var footerState: FooterState {
        if isLoadingMore { return .loading }
        if let loadMoreError { return .failed(loadMoreError) }
        if phase == .content, !articles.isEmpty, !canLoadMore { return .endOfList(endOfListMessage) }
        return .hidden
    }

    var query: ArticleQuery {
        if let activeSearchTerm {
            .search(term: activeSearchTerm, sortOrder: sortOrder)
        } else {
            .topHeadlines(country: country, category: category)
        }
    }

    /// Articles fetched per page; the list lazy-loads one page at a time.
    static let defaultPageSize = 10
    private static let maxSearchLength = 500
    private static let defaultEndOfListMessage = "You're all caught up."

    private let fetchArticles: FetchArticlesUseCase
    private let pageSize: Int
    private var nextPage = 1
    /// Bumped whenever a new first-page load starts, so slower responses to an
    /// older query can't overwrite the current one.
    private var generation = 0

    init(
        fetchArticles: FetchArticlesUseCase,
        initialCountry: Country = .unitedStates,
        pageSize: Int = NewsFeedViewModel.defaultPageSize
    ) {
        self.fetchArticles = fetchArticles
        self.country = initialCountry
        self.pageSize = pageSize
    }

    // MARK: - Filters

    func select(country: Country) async {
        await update { self.country = country }
    }

    func select(category: NewsCategory?) async {
        await update { self.category = category }
    }

    func select(sortOrder: ArticleSortOrder) async {
        await update { self.sortOrder = sortOrder }
    }

    /// Turns `searchText` into the active search. Blank text leaves search mode.
    func applySearch() async {
        let term = Self.normalized(searchText)
        await update { self.activeSearchTerm = term }
    }

    /// Applies a filter change and reloads only if it changes what is requested.
    private func update(_ change: () -> Void) async {
        let previous = query
        change()
        guard query != previous else { return }
        await loadFirstPage(clearingContent: true)
    }

    private static func normalized(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(maxSearchLength))
    }

    // MARK: - Loading

    func loadIfNeeded() async {
        guard phase == .idle else { return }
        await loadFirstPage(clearingContent: false)
    }

    /// Reloads the current query. Used for retry and pull-to-refresh, so old
    /// content stays visible until new content arrives.
    func reload() async {
        await loadFirstPage(clearingContent: false)
    }

    private func loadFirstPage(clearingContent: Bool) async {
        generation += 1
        let token = generation
        let requested = query

        isLoadingMore = false
        if clearingContent {
            articles = []
            nextPage = 1
            canLoadMore = false
            loadMoreError = nil
        }
        if articles.isEmpty { phase = .loading }

        do {
            let page = try await fetchArticles(requested, page: 1, pageSize: pageSize)
            guard token == generation else { return }
            articles = Self.unique(page.articles, appendedTo: [])
            nextPage = 2
            canLoadMore = page.hasMore
            loadMoreError = nil
            endOfListMessage = Self.defaultEndOfListMessage
            phase = .content
        } catch is CancellationError {
            guard token == generation else { return }
            if articles.isEmpty { phase = .idle }
        } catch {
            guard token == generation else { return }
            if articles.isEmpty {
                phase = .failed(error.localizedDescription)
            } else {
                alertMessage = error.localizedDescription
            }
        }
    }

    /// Call as rows appear; loads the next page when the last row shows up.
    func loadMoreIfNeeded(after article: Article) async {
        guard article.id == articles.last?.id, canLoadMore, loadMoreError == nil else { return }
        await loadMore()
    }

    func loadMore() async {
        guard canLoadMore, !isLoadingMore else { return }
        let token = generation
        let requested = query
        let requestedPage = nextPage
        isLoadingMore = true
        loadMoreError = nil
        defer { if token == generation { isLoadingMore = false } }

        do {
            let page = try await fetchArticles(requested, page: requestedPage, pageSize: pageSize)
            guard token == generation else { return }
            articles = Self.unique(page.articles, appendedTo: articles)
            nextPage += 1
            canLoadMore = page.hasMore
        } catch is CancellationError {
            return
        } catch NewsError.maximumResultsReached {
            guard token == generation else { return }
            canLoadMore = false
            endOfListMessage = NewsError.maximumResultsReached.localizedDescription
        } catch {
            guard token == generation else { return }
            loadMoreError = error.localizedDescription
        }
    }

    private static func unique(_ new: [Article], appendedTo existing: [Article]) -> [Article] {
        var seen = Set(existing.map(\.id))
        return existing + new.filter { seen.insert($0.id).inserted }
    }
}
