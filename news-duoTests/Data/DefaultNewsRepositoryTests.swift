import Foundation
import Testing
@testable import news_duo

struct DefaultNewsRepositoryTests {
    private let headlines = ArticleQuery.topHeadlines(country: .unitedStates, category: nil)
    private let configuration = NewsAPIConfiguration(apiKey: "test-key")

    private func repository(status: Int = 200, body: String) -> DefaultNewsRepository {
        DefaultNewsRepository(
            httpClient: StubHTTPClient { _ in (Data(body.utf8), status) },
            configuration: configuration
        )
    }

    private func okBody(totalResults: Int, titles: [String]) -> String {
        let articles = titles.enumerated().map { index, title in
            #"{"source":{"name":"S"},"title":"\#(title)","url":"https://example.com/\#(index)"}"#
        }
        return #"{"status":"ok","totalResults":\#(totalResults),"articles":[\#(articles.joined(separator: ","))]}"#
    }

    @Test func sendsKeyInHeaderNotInURL() async throws {
        let captured = CapturedRequest()
        let repo = DefaultNewsRepository(
            httpClient: StubHTTPClient { request in
                captured.set(request)
                return (Data(#"{"status":"ok","totalResults":0,"articles":[]}"#.utf8), 200)
            },
            configuration: configuration
        )

        _ = try await repo.articles(for: headlines, page: 2, pageSize: 20)

        let request = try #require(captured.value)
        #expect(request.value(forHTTPHeaderField: "X-Api-Key") == "test-key")
        let url = try #require(request.url)
        #expect(url.absoluteString.contains("test-key") == false)
        #expect(url.path() == "/v2/top-headlines")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.contains(URLQueryItem(name: "page", value: "2")))
        #expect(items.contains(URLQueryItem(name: "pageSize", value: "20")))
        #expect(items.contains(URLQueryItem(name: "country", value: "us")))
    }

    @Test func mapsArticlesAndReportsMorePages() async throws {
        let page = try await repository(body: okBody(totalResults: 50, titles: ["One", "Two"]))
            .articles(for: headlines, page: 1, pageSize: 2)

        #expect(page.articles.map(\.title) == ["One", "Two"])
        #expect(page.hasMore)
    }

    @Test func lastPageHasNoMore() async throws {
        let page = try await repository(body: okBody(totalResults: 3, titles: ["Three"]))
            .articles(for: headlines, page: 2, pageSize: 2)

        #expect(page.hasMore == false)
    }

    /// NewsAPI can filter after paging, so pages come back short or empty while
    /// the total says there is more (seen with sortBy=relevancy/popularity).
    @Test func shortOrEmptyPageStillHasMoreWhenTotalIsLarger() async throws {
        let short = try await repository(body: okBody(totalResults: 100, titles: ["Only one"]))
            .articles(for: headlines, page: 1, pageSize: 20)
        #expect(short.articles.count == 1)
        #expect(short.hasMore)

        let empty = try await repository(body: #"{"status":"ok","totalResults":43946,"articles":[]}"#)
            .articles(for: headlines, page: 1, pageSize: 20)
        #expect(empty.articles.isEmpty)
        #expect(empty.hasMore)
    }

    @Test func dropsRemovedPlaceholdersButKeepsPaging() async throws {
        let body = #"{"status":"ok","totalResults":10,"articles":[{"title":"[Removed]","url":"https://removed.com"}]}"#
        let page = try await repository(body: body).articles(for: headlines, page: 1, pageSize: 1)

        #expect(page.articles.isEmpty)
        #expect(page.hasMore)
    }

    @Test func throwsMissingKeyWithoutCallingTheNetwork() async {
        let repo = DefaultNewsRepository(
            httpClient: StubHTTPClient { _ in Issue.record("network should not be called"); return (Data(), 200) },
            configuration: NewsAPIConfiguration(apiKey: NewsAPIConfiguration.apiKeyPlaceholder)
        )

        await #expect(throws: NewsError.missingAPIKey) {
            try await repo.articles(for: headlines, page: 1, pageSize: 20)
        }
    }

    @Test(arguments: [
        (401, #"{"status":"error","code":"apiKeyInvalid","message":"bad"}"#, NewsError.invalidAPIKey),
        (429, #"{"status":"error","code":"rateLimited","message":"slow down"}"#, NewsError.rateLimited),
        (426, #"{"status":"error","code":"maximumResultsReached","message":"cap"}"#, NewsError.maximumResultsReached),
        (429, "not json", NewsError.rateLimited),
        (500, #"{"status":"error","code":"x","message":"boom"}"#, NewsError.server("boom")),
        (503, "not json", NewsError.server("The server returned an error (HTTP 503).")),
    ])
    func mapsErrors(status: Int, body: String, expected: NewsError) async {
        await #expect(throws: expected) {
            try await repository(status: status, body: body).articles(for: headlines, page: 1, pageSize: 20)
        }
    }

    @Test func mapsOfflineAndCancellation() async {
        let offline = DefaultNewsRepository(
            httpClient: StubHTTPClient { _ in throw URLError(.notConnectedToInternet) },
            configuration: configuration
        )
        await #expect(throws: NewsError.offline) {
            try await offline.articles(for: headlines, page: 1, pageSize: 20)
        }

        let cancelled = DefaultNewsRepository(
            httpClient: StubHTTPClient { _ in throw URLError(.cancelled) },
            configuration: configuration
        )
        await #expect(throws: CancellationError.self) {
            try await cancelled.articles(for: headlines, page: 1, pageSize: 20)
        }
    }
}

private final class CapturedRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var request: URLRequest?

    var value: URLRequest? { lock.withLock { request } }
    func set(_ request: URLRequest) { lock.withLock { self.request = request } }
}
