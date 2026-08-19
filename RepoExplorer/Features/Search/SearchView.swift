//
//  SearchView.swift
//  RepoExplorer
//
//  Created by Kaan Yeyrek on 19.08.2026.
//

import SwiftUI

struct SearchView: View {
    @State private var viewModel: SearchViewModel

    init(api: any GitHubAPIServing, cache: DiskCache) {
        _viewModel = State(initialValue: SearchViewModel(api: api, cache: cache))
    }

    var body: some View {
        content
            .navigationTitle("Repositories")
            .searchable(text: $viewModel.query, prompt: "Search GitHub repositories")
            .task { await viewModel.restoreLastSearch() }
            .task(id: viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)) {
                guard (try? await Task.sleep(for: .milliseconds(400))) != nil else { return }
                await viewModel.runSearch()
            }
    }
}

private extension SearchView {
    @ViewBuilder
    var content: some View {
        switch viewModel.phase {
        case .idle:
            ContentUnavailableView(
                "Search GitHub",
                systemImage: "magnifyingglass",
                description: Text("Find repositories by name, topic or keyword.")
            )
        case .loading where viewModel.repositories.isEmpty:
            ProgressView("Searching…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            ContentUnavailableView.search(text: viewModel.query)
        case .rateLimited(let resetAt) where viewModel.repositories.isEmpty:
            ContentUnavailableView {
                Label("Rate limit reached", systemImage: "hourglass")
            } description: {
                Text("GitHub limits unauthenticated search. Please wait a moment and try again.")
            } actions: {
                RetryButton(resetAt: resetAt) {
                    Task { await viewModel.runSearch() }
                }
            }
        case .failed(let message) where viewModel.repositories.isEmpty:
            ContentUnavailableView {
                Label("Something went wrong", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") {
                    Task { await viewModel.runSearch() }
                }
                .buttonStyle(.borderedProminent)
            }
        default:
            resultsList
        }
    }

    var resultsList: some View {
        List {
            ForEach(viewModel.repositories) { repository in
                NavigationLink(value: repository) {
                    RepoRow(repository: repository)
                }
                .onAppear {
                    Task { await viewModel.loadMoreIfNeeded(after: repository) }
                }
            }
            paginationFooter
        }
        .listStyle(.plain)
        .safeAreaInset(edge: .top) { topBanner }
    }

    @ViewBuilder
    var paginationFooter: some View {
        switch viewModel.pagination {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
        case .rateLimited(let resetAt):
            RateLimitBanner(resetAt: resetAt) {
                Task { await viewModel.retryPagination() }
            }
            .listRowSeparator(.hidden)
        case .failed:
            Button("Couldn't load more — tap to retry") {
                Task { await viewModel.retryPagination() }
            }
            .font(.footnote)
            .frame(maxWidth: .infinity)
            .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder
    var topBanner: some View {
        switch viewModel.phase {
        case .showingCached(let savedAt, let cachedQuery):
            OfflineBanner(savedAt: savedAt, query: cachedQuery)
        case .rateLimited(let resetAt):
            RateLimitBanner(resetAt: resetAt) {
                Task { await viewModel.runSearch() }
            }
        case .failed(let message):
            ErrorBanner(message: message) {
                Task { await viewModel.runSearch() }
            }
        case .loading:
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .padding(6)
                .background(.thinMaterial)
        default:
            EmptyView()
        }
    }
}
