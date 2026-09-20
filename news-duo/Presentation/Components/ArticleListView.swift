import SwiftUI

/// The list column shared by the News and Saved tabs. `header` and `footer`
/// are extra rows placed before and after the articles.
struct ArticleListView<Header: View, Footer: View>: View {
    let articles: [Article]
    @Binding var selection: Article.ID?
    var onRowAppear: (Article) -> Void = { _ in }
    @ViewBuilder var header: () -> Header
    @ViewBuilder var footer: () -> Footer

    @Environment(SavedArticlesViewModel.self) private var saved

    var body: some View {
        List(selection: $selection) {
            header()
            ForEach(articles) { article in
                let isSaved = saved.isSaved(article)
                ArticleRow(article: article, isSaved: isSaved)
                    .swipeActions(edge: .trailing) {
                        Button {
                            Task { await saved.toggle(article) }
                        } label: {
                            Label(isSaved ? "Unsave" : "Save", systemImage: isSaved ? "heart.slash" : "heart")
                        }
                        .tint(.pink)
                    }
                    .onAppear { onRowAppear(article) }
            }
            footer()
        }
        .listStyle(.plain)
    }
}

extension ArticleListView where Header == EmptyView, Footer == EmptyView {
    init(articles: [Article], selection: Binding<Article.ID?>, onRowAppear: @escaping (Article) -> Void = { _ in }) {
        self.init(
            articles: articles,
            selection: selection,
            onRowAppear: onRowAppear,
            header: { EmptyView() },
            footer: { EmptyView() }
        )
    }
}
