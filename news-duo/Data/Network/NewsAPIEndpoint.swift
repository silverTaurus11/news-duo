import Foundation

/// Maps an `ArticleQuery` to a NewsAPI request:
/// top headlines → `/top-headlines`, search → `/everything`.
nonisolated struct NewsAPIEndpoint {
    let query: ArticleQuery
    let page: Int
    let pageSize: Int

    func urlRequest(configuration: NewsAPIConfiguration) throws -> URLRequest {
        guard var components = URLComponents(
            url: configuration.baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        ) else { throw NewsError.invalidResponse }

        components.queryItems = queryItems
        // URLComponents leaves "+" as is, but servers read it as a space, and
        // NewsAPI uses "+term" as a search operator. Spaces are already %20.
        let encodedQuery = components.percentEncodedQuery ?? ""
        components.percentEncodedQuery = encodedQuery.replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url else { throw NewsError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue(configuration.apiKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private var path: String {
        switch query {
        case .topHeadlines: "top-headlines"
        case .search: "everything"
        }
    }

    private var queryItems: [URLQueryItem] {
        var items: [URLQueryItem]
        switch query {
        case let .topHeadlines(country, category):
            items = [URLQueryItem(name: "country", value: country.code)]
            if let category {
                items.append(URLQueryItem(name: "category", value: category.rawValue))
            }
        case let .search(term, sortOrder):
            items = [
                URLQueryItem(name: "q", value: term),
                URLQueryItem(name: "sortBy", value: sortOrder.apiValue),
            ]
        }
        items.append(URLQueryItem(name: "page", value: String(page)))
        items.append(URLQueryItem(name: "pageSize", value: String(pageSize)))
        return items
    }
}

private nonisolated extension ArticleSortOrder {
    var apiValue: String {
        switch self {
        case .relevancy: "relevancy"
        case .popularity: "popularity"
        case .newest: "publishedAt"
        }
    }
}
