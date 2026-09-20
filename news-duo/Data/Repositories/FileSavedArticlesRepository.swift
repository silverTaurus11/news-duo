import Foundation

/// Persists saved articles as a JSON file so they stay readable offline.
actor FileSavedArticlesRepository: SavedArticlesRepository {
    private let fileURL: URL
    private var cache: [Article]?

    init(fileURL: URL = FileSavedArticlesRepository.defaultFileURL()) {
        self.fileURL = fileURL
    }

    nonisolated static func defaultFileURL() -> URL {
        URL.applicationSupportDirectory.appending(path: "saved-articles.json")
    }

    func loadAll() throws -> [Article] {
        if let cache { return cache }
        let stored = read()
        cache = stored
        return stored
    }

    func contains(id: Article.ID) throws -> Bool {
        try loadAll().contains { $0.id == id }
    }

    func save(_ article: Article) throws {
        var articles = try loadAll()
        articles.removeAll { $0.id == article.id }
        articles.insert(article, at: 0)
        try write(articles)
    }

    func remove(id: Article.ID) throws {
        var articles = try loadAll()
        articles.removeAll { $0.id == id }
        try write(articles)
    }

    // MARK: - Disk

    private func read() -> [Article] {
        // An unreadable file is treated as empty; the next save replaces it.
        guard let data = try? Data(contentsOf: fileURL),
              let articles = try? Self.decoder.decode([Article].self, from: data)
        else { return [] }
        return articles
    }

    private func write(_ articles: [Article]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Self.encoder.encode(articles).write(to: fileURL, options: .atomic)
        cache = articles
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
