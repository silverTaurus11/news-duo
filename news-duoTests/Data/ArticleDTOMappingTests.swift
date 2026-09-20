import Foundation
import Testing
@testable import news_duo

struct ArticleDTOMappingTests {
    private func dto(
        title: String? = "A title",
        url: String? = "https://example.com/a",
        content: String? = nil,
        publishedAt: String? = nil
    ) -> ArticleDTO {
        ArticleDTO(
            source: SourceDTO(name: "Example News"),
            author: " Jane Doe ",
            title: title,
            description: "  A description  ",
            url: url,
            urlToImage: "https://example.com/a.jpg",
            publishedAt: publishedAt,
            content: content
        )
    }

    @Test func mapsAndTrimsFields() throws {
        let article = try #require(dto().toDomain())

        #expect(article.title == "A title")
        #expect(article.summary == "A description")
        #expect(article.author == "Jane Doe")
        #expect(article.sourceName == "Example News")
        #expect(article.imageURL == URL(string: "https://example.com/a.jpg"))
        #expect(article.id == "https://example.com/a")
    }

    @Test func dropsRemovedPlaceholders() {
        #expect(dto(title: "[Removed]", url: "https://removed.com").toDomain() == nil)
    }

    @Test func dropsArticlesWithoutUsableTitleOrURL() {
        #expect(dto(title: nil).toDomain() == nil)
        #expect(dto(title: "   ").toDomain() == nil)
        #expect(dto(url: nil).toDomain() == nil)
        #expect(dto(url: "not a url").toDomain() == nil)
        #expect(dto(url: "ftp://example.com/a").toDomain() == nil)
    }

    @Test func stripsTruncationMarkerFromContent() {
        let article = dto(content: "Some text that was cut off… [+1234 chars]").toDomain()
        #expect(article?.content == "Some text that was cut off…")
    }

    @Test func parsesISO8601Dates() {
        let article = dto(publishedAt: "2026-09-20T12:30:00Z").toDomain()
        #expect(article?.publishedAt == Date(timeIntervalSince1970: 1_789_907_400))
    }

    @Test func ignoresUnparseableDates() {
        #expect(dto(publishedAt: "yesterday").toDomain()?.publishedAt == nil)
    }
}
