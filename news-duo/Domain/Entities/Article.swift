import Foundation

/// A news article. Identity is the article URL because NewsAPI provides no id.
nonisolated struct Article: Identifiable, Hashable, Codable, Sendable {
    let title: String
    let summary: String?
    let content: String?
    let author: String?
    let sourceName: String
    let url: URL
    let imageURL: URL?
    let publishedAt: Date?

    var id: String { url.absoluteString }
}

/// One page of results. `hasMore` is decided by the data source: a page can be
/// short or even empty while more results still exist.
nonisolated struct ArticlesPage: Equatable, Sendable {
    let articles: [Article]
    let hasMore: Bool
}
