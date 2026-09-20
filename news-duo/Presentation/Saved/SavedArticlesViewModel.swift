import Foundation
import Observation

/// Single source of truth for saved state, shared by the list, detail and
/// Saved tab so the heart always agrees everywhere.
@Observable
final class SavedArticlesViewModel {
    private(set) var articles: [Article] = []
    private(set) var savedIDs: Set<Article.ID> = []
    var errorMessage: String?

    private let getSavedArticles: GetSavedArticlesUseCase
    private let toggleSavedArticle: ToggleSavedArticleUseCase

    init(getSavedArticles: GetSavedArticlesUseCase, toggleSavedArticle: ToggleSavedArticleUseCase) {
        self.getSavedArticles = getSavedArticles
        self.toggleSavedArticle = toggleSavedArticle
    }

    func isSaved(_ article: Article) -> Bool {
        savedIDs.contains(article.id)
    }

    func load() async {
        do {
            apply(try await getSavedArticles())
        } catch {
            errorMessage = "Couldn't load saved articles. \(error.localizedDescription)"
        }
    }

    func toggle(_ article: Article) async {
        do {
            let isNowSaved = try await toggleSavedArticle(article)
            var updated = articles.filter { $0.id != article.id }
            if isNowSaved { updated.insert(article, at: 0) }
            apply(updated)
        } catch {
            errorMessage = "Couldn't update saved articles. \(error.localizedDescription)"
        }
    }

    private func apply(_ articles: [Article]) {
        self.articles = articles
        savedIDs = Set(articles.map(\.id))
    }
}
