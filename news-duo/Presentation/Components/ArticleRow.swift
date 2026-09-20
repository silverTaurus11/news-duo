import SwiftUI

struct ArticleRow: View {
    let article: Article
    let isSaved: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(article.title)
                    .font(.headline)
                    .lineLimit(3)

                HStack(spacing: 4) {
                    if isSaved {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.pink)
                            .accessibilityLabel("Saved")
                    }
                    Text(article.sourceName)
                    if let date = article.publishedAt {
                        Text("·")
                        Text(date, format: .relative(presentation: .named))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            RemoteImageView(url: article.imageURL)
                .frame(width: 84, height: 84)
                .clipShape(.rect(cornerRadius: 10))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
