import SwiftUI

/// The two-pane layout: list on the left, detail on the right.
///
/// Per the iPhone Duo HIG, `NavigationSplitView` shows both panes on the inner
/// (regular width) display, collapses to a single pane on the outer (compact
/// width) display, and adapts around the fold. This is the only place that
/// decides that layout, so any Duo-specific tuning belongs here.
struct ArticlesSplitView<Sidebar: View>: View {
    let articles: [Article]
    let selection: Article.ID?
    @ViewBuilder var sidebar: () -> Sidebar

    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar()
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 460)
        } detail: {
            if let article = articles.first(where: { $0.id == selection }) {
                ArticleDetailView(article: article)
                    .id(article.id)
            } else {
                ContentUnavailableView(
                    "Select an Article",
                    systemImage: "newspaper",
                    description: Text("Pick a story from the list to read it here.")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
