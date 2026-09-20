import Foundation

/// Offline sample data, used while no NewsAPI key is configured so the UI can
/// still be explored. Never used once a real key is set.
nonisolated struct DemoNewsRepository: NewsRepository {
    func articles(for query: ArticleQuery, page: Int, pageSize: Int) async throws -> ArticlesPage {
        try await Task.sleep(for: .milliseconds(400))

        // Country, category and sort order are ignored; only a search term filters.
        var all = Self.sampleArticles()
        if case .search(let term, _) = query {
            all = all.filter { article in
                [article.title, article.summary ?? ""].contains { $0.localizedStandardContains(term) }
            }
        }
        let start = (page - 1) * pageSize
        guard start < all.count else { return ArticlesPage(articles: [], hasMore: false) }
        let end = min(start + pageSize, all.count)
        return ArticlesPage(articles: Array(all[start..<end]), hasMore: end < all.count)
    }

    private static func sampleArticles() -> [Article] {
        let now = Date()
        let body = """
        This is sample text shown in demo mode. Add your NewsAPI key (see the README) to load real headlines. \
        On iPhone Duo's inner display this article appears next to the list; on the outer display it opens as its own screen.
        """

        return samples.enumerated().map { index, sample in
            Article(
                title: sample.title,
                summary: sample.summary,
                content: body,
                author: sample.author,
                sourceName: sample.source,
                url: URL(string: "https://example.com/demo/\(index + 1)")!,
                imageURL: URL(string: "https://picsum.photos/seed/newsduo\(index + 1)/800/450"),
                publishedAt: now.addingTimeInterval(TimeInterval(-index * 5_400))
            )
        }
    }

    private static let samples: [(title: String, summary: String, author: String?, source: String)] = [
        ("Foldable phones push apps toward adaptive layouts", "Developers are rethinking screens as two-pane designs become the default on larger displays.", "Dana Whitfield", "Daily Circuit"),
        ("City opens its longest cycling bridge to the public", "The 1.2 km crossing links two districts and cuts commute times by a quarter.", "Marco Lindqvist", "Metro Ledger"),
        ("Researchers report a faster way to recycle lithium batteries", "The process recovers over 95 percent of key metals using less energy than smelting.", nil, "Science Weekly"),
        ("Central bank holds rates steady as inflation cools", "Analysts expect the first cut early next year if the trend continues.", "Priya Nair", "Market Wire"),
        ("Local team clinches title with last-minute goal", "A packed stadium watched the decisive strike in the 92nd minute.", "Tomás Herrera", "Sports Desk"),
        ("New study links short daily walks to better sleep", "Ten minutes of walking was enough to show measurable improvements across the study group.", "Dr. Amelia Chen", "Health Today"),
        ("Streaming service unveils its autumn lineup", "Six original series and two feature films headline the season.", "Jordan Blake", "Screen Report"),
        ("Coastal towns brace for the season's first big storm", "Officials urge residents to secure property and avoid low-lying roads.", nil, "Regional Herald"),
        ("Open-source community ships long-awaited compiler update", "The release brings faster builds and clearer diagnostics.", "Ines Duarte", "Dev Journal"),
        ("Museum reopens after a three-year restoration", "Visitors can now see the newly restored east wing and its permanent collection.", "Karim Haddad", "Culture Post"),
        ("Farmers adopt sensors to cut water use", "Early adopters report savings of up to 30 percent without lower yields.", "Lena Okafor", "AgriNews"),
        ("Space agency confirms date for next crewed launch", "Four astronauts will spend six months aboard the orbital station.", "Victor Almeida", "Orbit Review"),
    ]
}
