import Foundation

nonisolated struct DefaultNewsRepository: NewsRepository {
    let httpClient: any HTTPClient
    let configuration: NewsAPIConfiguration

    func articles(for query: ArticleQuery, page: Int, pageSize: Int) async throws -> ArticlesPage {
        guard configuration.hasAPIKey else { throw NewsError.missingAPIKey }

        let request = try NewsAPIEndpoint(query: query, page: page, pageSize: pageSize)
            .urlRequest(configuration: configuration)

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await httpClient.send(request)
        } catch let error as URLError {
            throw Self.map(error)
        }

        return try Self.makePage(from: data, statusCode: response.statusCode, page: page, pageSize: pageSize)
    }

    // MARK: - Response handling

    private static func makePage(from data: Data, statusCode: Int, page: Int, pageSize: Int) throws -> ArticlesPage {
        let dto = try? JSONDecoder().decode(NewsAPIResponseDTO.self, from: data)

        guard (200..<300).contains(statusCode), dto?.status == "ok" else {
            throw map(errorCode: dto?.code, message: dto?.message, statusCode: statusCode)
        }
        guard let dto, let rawArticles = dto.articles else { throw NewsError.invalidResponse }

        // Based on the requested page size, not the returned count: NewsAPI can
        // filter results after paging (depending on plan and sort order), so a
        // page may be short or empty while later pages still have articles.
        return ArticlesPage(
            articles: rawArticles.compactMap { $0.toDomain() },
            hasMore: page * pageSize < (dto.totalResults ?? 0)
        )
    }

    private static func map(errorCode: String?, message: String?, statusCode: Int) -> NewsError {
        switch errorCode {
        case "apiKeyMissing", "apiKeyInvalid", "apiKeyDisabled": .invalidAPIKey
        case "rateLimited", "apiKeyExhausted": .rateLimited
        case "maximumResultsReached": .maximumResultsReached
        default:
            switch statusCode {
            case 401: .invalidAPIKey
            case 429: .rateLimited
            default: .server(message ?? "The server returned an error (HTTP \(statusCode)).")
            }
        }
    }

    private static func map(_ error: URLError) -> Error {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            NewsError.offline
        case .cancelled:
            CancellationError()
        default:
            NewsError.server(error.localizedDescription)
        }
    }
}
