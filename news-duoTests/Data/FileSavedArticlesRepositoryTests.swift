import Foundation
import Testing
@testable import news_duo

struct FileSavedArticlesRepositoryTests {
    private func makeFileURL() -> URL {
        URL.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "saved.json")
    }

    @Test func startsEmptyWhenNoFileExists() async throws {
        let repo = FileSavedArticlesRepository(fileURL: makeFileURL())
        #expect(try await repo.loadAll().isEmpty)
    }

    @Test func savedArticlesSurviveANewInstance() async throws {
        let url = makeFileURL()
        var article = Article.sample(1)
        article = Article(
            title: article.title, summary: article.summary, content: article.content,
            author: "Jane", sourceName: article.sourceName, url: article.url,
            imageURL: URL(string: "https://example.com/i.jpg"),
            publishedAt: Date(timeIntervalSince1970: 1_789_907_400)
        )

        try await FileSavedArticlesRepository(fileURL: url).save(article)
        let reloaded = try await FileSavedArticlesRepository(fileURL: url).loadAll()

        #expect(reloaded == [article])
    }

    @Test func newestSavedComesFirstAndSavingTwiceDoesNotDuplicate() async throws {
        let repo = FileSavedArticlesRepository(fileURL: makeFileURL())

        try await repo.save(.sample(1))
        try await repo.save(.sample(2))
        try await repo.save(.sample(1))

        #expect(try await repo.loadAll().map(\.id) == [Article.sample(1).id, Article.sample(2).id])
    }

    @Test func removeAndContains() async throws {
        let repo = FileSavedArticlesRepository(fileURL: makeFileURL())
        try await repo.save(.sample(1))
        #expect(try await repo.contains(id: Article.sample(1).id))

        try await repo.remove(id: Article.sample(1).id)

        #expect(try await repo.contains(id: Article.sample(1).id) == false)
        #expect(try await repo.loadAll().isEmpty)
    }

    @Test func corruptFileIsTreatedAsEmptyAndRecoversOnSave() async throws {
        let url = makeFileURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        let repo = FileSavedArticlesRepository(fileURL: url)

        #expect(try await repo.loadAll().isEmpty)
        try await repo.save(.sample(1))

        #expect(try await FileSavedArticlesRepository(fileURL: url).loadAll().count == 1)
    }
}
