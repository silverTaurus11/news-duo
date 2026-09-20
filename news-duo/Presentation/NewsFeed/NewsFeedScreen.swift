import SwiftUI

struct NewsFeedScreen: View {
    @Bindable var viewModel: NewsFeedViewModel
    let isDemoMode: Bool

    @State private var selection: Article.ID?
    @State private var isShowingCountryPicker = false

    var body: some View {
        ArticlesSplitView(articles: viewModel.articles, selection: selection) {
            ArticleListView(
                articles: viewModel.articles,
                selection: $selection,
                onRowAppear: { article in
                    Task { await viewModel.loadMoreIfNeeded(after: article) }
                }
            ) {
                filterBar
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } footer: {
                loadMoreFooter
            }
            .overlay { stateOverlay }
            .navigationTitle(viewModel.isSearching ? "Search" : "Top Headlines")
            .navigationSubtitle(subtitle)
            .searchable(text: $viewModel.searchText, prompt: "Search all news")
            .onSubmit(of: .search) { Task { await viewModel.applySearch() } }
            .onChange(of: viewModel.searchText) { _, text in
                // Clearing the field leaves search mode and returns to headlines.
                if text.isEmpty { Task { await viewModel.applySearch() } }
            }
            .toolbar {
                if !viewModel.isSearching {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isShowingCountryPicker = true
                        } label: {
                            // Icon-only on screen (the flag); the title is for VoiceOver,
                            // the overflow menu and bars that show titles.
                            Label {
                                Text(viewModel.country.name)
                            } icon: {
                                FlagIcon.image(for: viewModel.country)
                                    .scaledToFit()
                                    .frame(height: 22)
                            }
                        }
                        .accessibilityHint("Opens the country picker")
                    }
                    .visibilityPriority(.high)
                }
            }
            .sheet(isPresented: $isShowingCountryPicker) {
                CountryPickerView(selection: viewModel.country) { country in
                    Task { await viewModel.select(country: country) }
                }
            }
            .refreshable { await viewModel.reload() }
            .task { await viewModel.loadIfNeeded() }
            .alert("Couldn't refresh", isPresented: alertBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
        }
    }

    // MARK: - Filters

    @ViewBuilder
    private var filterBar: some View {
        if viewModel.isSearching {
            FilterChipBar(
                chips: ArticleSortOrder.allCases.map { .init(value: $0, title: $0.title) },
                selection: viewModel.sortOrder
            ) { order in
                Task { await viewModel.select(sortOrder: order) }
            }
        } else {
            FilterChipBar(
                chips: categoryChips,
                selection: viewModel.category
            ) { category in
                Task { await viewModel.select(category: category) }
            }
        }
    }

    private var categoryChips: [FilterChipBar<NewsCategory?>.Chip] {
        [.init(value: nil, title: "All")] + NewsCategory.allCases.map { .init(value: $0, title: $0.title) }
    }

    private var subtitle: String {
        if isDemoMode { return "Demo data — add your NewsAPI key" }
        if let term = viewModel.activeSearchTerm { return "“\(term)”" }
        return ""
    }

    // MARK: - States

    @ViewBuilder
    private var stateOverlay: some View {
        switch viewModel.phase {
        case .idle:
            ProgressView("Loading…")
        case .loading where viewModel.articles.isEmpty:
            ProgressView("Loading…")
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't Load News", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await viewModel.reload() } }
                    .buttonStyle(.borderedProminent)
            }
        case .content where viewModel.articles.isEmpty:
            emptyState
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if let term = viewModel.activeSearchTerm {
            ContentUnavailableView {
                Label("No Results", systemImage: "magnifyingglass")
            } description: {
                Text("NewsAPI returned no articles for “\(term)”. Try another keyword or sort order.")
            }
        } else {
            ContentUnavailableView {
                Label("No Headlines", systemImage: "newspaper")
            } description: {
                Text("NewsAPI returned no top headlines for \(viewModel.country.flag) \(viewModel.country.name). Coverage varies by country, so try another one, or search.")
            }
        }
    }

    /// The row after the last article: spinner while the next page loads, the
    /// reason plus a retry button if it failed, a note once everything is loaded.
    @ViewBuilder
    private var loadMoreFooter: some View {
        switch viewModel.footerState {
        case .hidden:
            EmptyView()
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                Text("Loading more…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .listRowSeparator(.hidden)
            .accessibilityElement(children: .combine)
        case .failed(let message):
            VStack(spacing: 8) {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") { Task { await viewModel.loadMore() } }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .listRowSeparator(.hidden)
        case .endOfList(let message):
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.alertMessage = nil } }
        )
    }
}
