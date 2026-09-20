import Foundation

nonisolated enum NewsError: Error, Equatable, LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case rateLimited
    case maximumResultsReached
    case offline
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "No NewsAPI key is configured. Add one to Secrets.plist or set NEWS_API_KEY."
        case .invalidAPIKey:
            "The NewsAPI key was rejected. Check the key in Secrets.plist or NEWS_API_KEY."
        case .rateLimited:
            "Too many requests. Please try again later."
        case .maximumResultsReached:
            "No more results are available for this plan."
        case .offline:
            "You appear to be offline. Check your connection and try again."
        case .invalidResponse:
            "The server sent a response the app couldn't read."
        case .server(let message):
            message
        }
    }
}
