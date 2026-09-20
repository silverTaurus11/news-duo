import SwiftUI

/// Fills whatever frame it is given. While the image downloads it shows a
/// spinner; with no URL, or if the download fails, it shows a fallback icon.
struct RemoteImageView: View {
    let url: URL?

    var body: some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    placeholder { Image(systemName: "photo.badge.exclamationmark") }
                default:
                    placeholder { ProgressView().controlSize(.small) }
                }
            }
            .accessibilityHidden(true)
        } else {
            placeholder { Image(systemName: "photo") }
                .accessibilityHidden(true)
        }
    }

    private func placeholder<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                content().foregroundStyle(.tertiary)
            }
    }
}
