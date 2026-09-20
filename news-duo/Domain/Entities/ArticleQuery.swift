/// What the user is asking the news source for.
nonisolated enum ArticleQuery: Hashable, Sendable {
    /// Top headlines for a country, optionally narrowed to one category.
    case topHeadlines(country: Country, category: NewsCategory?)
    /// A keyword search across all articles.
    case search(term: String, sortOrder: ArticleSortOrder)
}
