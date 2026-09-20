import SwiftUI

struct ArticleDetailView: View {
    let article: Article

    @Environment(SavedArticlesViewModel.self) private var saved

    var body: some View {
        let isSaved = saved.isSaved(article)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if article.imageURL != nil {
                    Color.clear
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .overlay { RemoteImageView(url: article.imageURL) }
                        .clipShape(.rect(cornerRadius: 14))
                }

                Text(article.title)
                    .font(.title.bold())

                metadata

                if let summary = article.summary {
                    Text(summary)
                        .font(.title3)
                }

                if let content = article.extraContent {
                    Text(content)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Link(destination: article.url) {
                    Label("Read full article", systemImage: "safari")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Vertical bars (Duo's outer display, or beside a detail pane) show
            // icons only and collapse extra items into an overflow menu. Every
            // item has an icon and a title, and Save outranks Share.
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await saved.toggle(article) }
                } label: {
                    Label(isSaved ? "Saved" : "Save", systemImage: isSaved ? "heart.fill" : "heart")
                }
                .tint(isSaved ? .pink : nil)
                .sensoryFeedback(.selection, trigger: isSaved)
            }
            .visibilityPriority(.high)

            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: article.url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            .visibilityPriority(.low)
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(article.sourceName)
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 4) {
                if let author = article.author {
                    Text(author)
                }
                if article.author != nil, article.publishedAt != nil {
                    Text("·")
                }
                if let date = article.publishedAt {
                    Text(date, format: .dateTime.day().month(.abbreviated).year().hour().minute())
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }
}

private extension Article {
    /// NewsAPI's `content` usually starts with the same text as `description`;
    /// only show it when it adds something.
    var extraContent: String? {
        guard let content else { return nil }
        guard let summary else { return content }
        return content.hasPrefix(summary.prefix(40)) ? nil : content
    }
}
