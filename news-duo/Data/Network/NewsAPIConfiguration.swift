import Foundation

nonisolated struct NewsAPIConfiguration: Sendable {
    static let apiKeyPlaceholder = "YOUR_NEWSAPI_KEY"

    var baseURL = URL(string: "https://newsapi.org/v2")!
    var apiKey: String

    var hasAPIKey: Bool {
        !apiKey.isEmpty && apiKey != Self.apiKeyPlaceholder
    }
}
