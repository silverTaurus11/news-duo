import Foundation
import Testing
@testable import news_duo

struct NewsAPIEndpointTests {
    private let configuration = NewsAPIConfiguration(apiKey: "test-key")

    private func request(_ query: ArticleQuery, page: Int = 1, pageSize: Int = 20) throws -> URLRequest {
        try NewsAPIEndpoint(query: query, page: page, pageSize: pageSize).urlRequest(configuration: configuration)
    }

    private func items(of request: URLRequest) throws -> [String: String] {
        let url = try #require(request.url)
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value ?? "") })
    }

    @Test func topHeadlinesUsesCountryAndCategory() throws {
        let request = try request(.topHeadlines(country: Country(code: "GB"), category: .technology), page: 3)
        let items = try items(of: request)

        #expect(request.url?.path() == "/v2/top-headlines")
        #expect(items == ["country": "gb", "category": "technology", "page": "3", "pageSize": "20"])
    }

    @Test func topHeadlinesOmitsCategoryWhenAll() throws {
        let items = try items(of: request(.topHeadlines(country: .unitedStates, category: nil)))

        #expect(items["category"] == nil)
        #expect(items["country"] == "us")
    }

    @Test(arguments: [
        (ArticleSortOrder.relevancy, "relevancy"),
        (ArticleSortOrder.popularity, "popularity"),
        (ArticleSortOrder.newest, "publishedAt"),
    ])
    func searchUsesEverythingWithSortBy(sortOrder: ArticleSortOrder, expected: String) throws {
        let request = try request(.search(term: "iphone duo", sortOrder: sortOrder))
        let items = try items(of: request)

        #expect(request.url?.path() == "/v2/everything")
        #expect(items["q"] == "iphone duo")
        #expect(items["sortBy"] == expected)
        #expect(items["country"] == nil)
    }

    @Test func searchOperatorsSurviveEncoding() throws {
        let request = try request(.search(term: "+apple -juice \"exact & phrase\"", sortOrder: .newest))
        let query = try #require(request.url?.query())

        // A literal "+" must be sent as %2B or the server reads it as a space.
        #expect(query.contains("q=%2Bapple%20-juice%20"))
        #expect(!query.contains("+"))
        #expect(try items(of: request)["q"] == "+apple -juice \"exact & phrase\"")
    }

    @Test func keyGoesInHeaderOnly() throws {
        let request = try request(.search(term: "x", sortOrder: .relevancy))

        #expect(request.value(forHTTPHeaderField: "X-Api-Key") == "test-key")
        #expect(request.url?.absoluteString.contains("test-key") == false)
    }
}
