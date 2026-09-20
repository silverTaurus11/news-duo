import SwiftUI

struct SavedScreen: View {
    @Environment(SavedArticlesViewModel.self) private var saved

    @State private var selection: Article.ID?

    var body: some View {
        ArticlesSplitView(articles: saved.articles, selection: selection) {
            ArticleListView(articles: saved.articles, selection: $selection)
                .overlay {
                    if saved.articles.isEmpty {
                        ContentUnavailableView(
                            "No Saved Articles",
                            systemImage: "heart",
                            description: Text("Tap the heart on an article to keep it here.")
                        )
                    }
                }
                .navigationTitle("Saved")
        }
    }
}
