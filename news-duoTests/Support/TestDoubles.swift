import Foundation
@testable import news_duo

extension Article {
    static func sample(_ number: Int = 1) -> Article {
        Article(
            title: "Headline \(number)",
            summary: "Summary \(number)",
            content: nil,
            author: nil,
            sourceName: "Source",
            url: URL(string: "https://example.com/articles/\(number)")!,
            imageURL: nil,
            publishedAt: nil
        )
    }
}

/// Serves pre-programmed results, one per call, and records every request.
actor FakeNewsRepository: NewsRepository {
    struct Request: Equatable {
        let query: ArticleQuery
        let page: Int
        let pageSize: Int
    }

    private var results: [Result<ArticlesPage, NewsError>]
    private(set) var requests: [Request] = []

    var requestedPages: [Int] { requests.map(\.page) }
    var requestedQueries: [ArticleQuery] { requests.map(\.query) }

    init(results: [Result<ArticlesPage, NewsError>]) {
        self.results = results
    }

    func articles(for query: ArticleQuery, page: Int, pageSize: Int) async throws -> ArticlesPage {
        requests.append(Request(query: query, page: page, pageSize: pageSize))
        guard !results.isEmpty else { throw NewsError.invalidResponse }
        return try results.removeFirst().get()
    }
}

/// Answers by query (not by call order), each after its own delay. Lets a test
/// make an older request finish after a newer one.
actor KeyedNewsRepository: NewsRepository {
    struct Response {
        let delay: Duration
        let page: ArticlesPage
    }

    private let responses: [ArticleQuery: Response]
    private(set) var requestCount = 0

    init(responses: [ArticleQuery: Response]) {
        self.responses = responses
    }

    func articles(for query: ArticleQuery, page: Int, pageSize: Int) async throws -> ArticlesPage {
        requestCount += 1
        guard let response = responses[query] else { throw NewsError.invalidResponse }
        try await Task.sleep(for: response.delay)
        return response.page
    }
}

actor InMemorySavedArticlesRepository: SavedArticlesRepository {
    private var articles: [Article]
    var shouldFail = false

    init(articles: [Article] = []) {
        self.articles = articles
    }

    func setShouldFail(_ value: Bool) { shouldFail = value }

    func loadAll() throws -> [Article] {
        if shouldFail { throw NewsError.invalidResponse }
        return articles
    }

    func contains(id: Article.ID) throws -> Bool {
        if shouldFail { throw NewsError.invalidResponse }
        return articles.contains { $0.id == id }
    }

    func save(_ article: Article) throws {
        if shouldFail { throw NewsError.invalidResponse }
        articles.insert(article, at: 0)
    }

    func remove(id: Article.ID) throws {
        if shouldFail { throw NewsError.invalidResponse }
        articles.removeAll { $0.id == id }
    }
}

struct StubHTTPClient: HTTPClient {
    let handler: @Sendable (URLRequest) throws -> (Data, Int)

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, status) = try handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (data, response)
    }
}
