import Foundation

enum AppConfig {
    /// NewsAPI credentials (https://newsapi.org).
    ///
    /// The key is looked up in this order, and never lives in source control:
    ///  1. the `NEWS_API_KEY` environment variable (Xcode ▸ Edit Scheme ▸ Run ▸ Arguments),
    ///  2. a git-ignored `Secrets.plist` in the app target with a `NEWS_API_KEY` string
    ///     (copy `Secrets.example.plist` from the repository root),
    ///  3. otherwise `NewsAPIConfiguration.apiKeyPlaceholder`, which runs the app on demo data.
    ///
    /// A key compiled into the app can be extracted from the binary, so for a shipped
    /// app route requests through your own backend instead.
    static let newsAPI = NewsAPIConfiguration(apiKey: resolveAPIKey())

    private static func resolveAPIKey() -> String {
        if let key = ProcessInfo.processInfo.environment["NEWS_API_KEY"], !key.isEmpty {
            return key
        }
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let secrets = NSDictionary(contentsOf: url),
           let key = secrets["NEWS_API_KEY"] as? String, !key.isEmpty {
            return key
        }
        return NewsAPIConfiguration.apiKeyPlaceholder
    }
}
