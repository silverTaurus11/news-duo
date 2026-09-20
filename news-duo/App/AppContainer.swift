import Foundation

/// Composition root: the only place that knows concrete types from every layer.
final class AppContainer {
    let isDemoMode: Bool
    let feed: NewsFeedViewModel
    let saved: SavedArticlesViewModel

    init(
        configuration: NewsAPIConfiguration,
        defaultCountry: Country = .unitedStates,
        savedArticlesFileURL: URL = FileSavedArticlesRepository.defaultFileURL()
    ) {
        isDemoMode = !configuration.hasAPIKey

        let newsRepository: any NewsRepository = isDemoMode
            ? DemoNewsRepository()
            : DefaultNewsRepository(httpClient: URLSessionHTTPClient(), configuration: configuration)
        let savedRepository = FileSavedArticlesRepository(fileURL: savedArticlesFileURL)

        feed = NewsFeedViewModel(
            fetchArticles: FetchArticlesUseCase(repository: newsRepository),
            initialCountry: defaultCountry
        )
        saved = SavedArticlesViewModel(
            getSavedArticles: GetSavedArticlesUseCase(repository: savedRepository),
            toggleSavedArticle: ToggleSavedArticleUseCase(repository: savedRepository)
        )
    }
}
