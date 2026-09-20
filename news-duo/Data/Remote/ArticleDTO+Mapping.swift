import Foundation

nonisolated extension ArticleDTO {
    /// Returns `nil` for entries that aren't usable articles, such as the
    /// `[Removed]` placeholders NewsAPI returns for taken-down stories.
    func toDomain() -> Article? {
        guard
            let title = Self.clean(title), title != "[Removed]",
            let url = Self.webURL(url)
        else { return nil }

        return Article(
            title: title,
            summary: Self.clean(description),
            content: Self.clean(Self.stripTruncationMarker(content)),
            author: Self.clean(author),
            sourceName: Self.clean(source?.name) ?? url.host() ?? "Unknown source",
            url: url,
            imageURL: Self.webURL(urlToImage),
            publishedAt: publishedAt.flatMap { try? Date($0, strategy: .iso8601) }
        )
    }

    private static func clean(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }

    private static func webURL(_ string: String?) -> URL? {
        guard let string, let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return nil }
        return url
    }

    /// NewsAPI truncates `content` and appends "[+1234 chars]".
    private static func stripTruncationMarker(_ text: String?) -> String? {
        text?.replacingOccurrences(
            of: #"\s*\[\+\d+ chars\]$"#,
            with: "",
            options: .regularExpression
        )
    }
}
