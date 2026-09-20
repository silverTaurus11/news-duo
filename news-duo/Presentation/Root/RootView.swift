import SwiftUI

struct RootView: View {
    let container: AppContainer

    var body: some View {
        @Bindable var saved = container.saved

        TabView {
            Tab("News", systemImage: "newspaper") {
                NewsFeedScreen(viewModel: container.feed, isDemoMode: container.isDemoMode)
            }
            Tab("Saved", systemImage: "heart") {
                SavedScreen()
            }
            .badge(saved.articles.count)
        }
        .environment(container.saved)
        .task { await container.saved.load() }
        .alert("Something went wrong", isPresented: Binding(
            get: { saved.errorMessage != nil },
            set: { if !$0 { saved.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saved.errorMessage ?? "")
        }
    }
}

#Preview {
    RootView(container: AppContainer(
        configuration: AppConfig.newsAPI,
        savedArticlesFileURL: URL.temporaryDirectory.appending(path: "preview-saved.json")
    ))
}
