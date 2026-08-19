//
//  DetailView.swift
//  RepoExplorer
//
//  Created by Kaan Yeyrek on 19.08.2026.
//

import SwiftUI

struct DetailView: View {
    @Environment(BookmarkStore.self) private var bookmarks

    @State private var viewModel: DetailViewModel

    init(repository: Repository, api: any GitHubAPIServing, cache: DiskCache) {
        _viewModel = State(initialValue: DetailViewModel(repository: repository, api: api, cache: cache))
    }

    var body: some View {
        List {
            headerSection
            statsSection
            contributorsSection
        }
        .navigationTitle(viewModel.repository.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    bookmarks.toggle(viewModel.repository)
                } label: {
                    Image(systemName: bookmarks.isBookmarked(viewModel.repository) ? "bookmark.fill" : "bookmark")
                }
            }
        }
        .task { await viewModel.loadContributors() }
    }
}

private extension DetailView {
    var headerSection: some View {
        Section {
            HStack(spacing: 12) {
                AsyncImage(url: viewModel.repository.owner.avatarURL) { image in
                    image.resizable()
                } placeholder: {
                    Color(.secondarySystemFill)
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.repository.fullName)
                        .font(.headline)
                    if let language = viewModel.repository.language {
                        Text(language)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let description = viewModel.repository.description {
                Text(description)
                    .font(.body)
            }

            Link(destination: viewModel.repository.htmlURL) {
                Label("View on GitHub", systemImage: "safari")
            }
        }
    }

    var statsSection: some View {
        Section("Stats") {
            LabeledContent {
                Text(viewModel.repository.stars.formatted())
            } label: {
                Label("Stars", systemImage: "star")
            }
            LabeledContent {
                Text(viewModel.repository.openIssues.formatted())
            } label: {
                Label("Open issues", systemImage: "exclamationmark.circle")
            }
        }
    }

    @ViewBuilder
    var contributorsSection: some View {
        Section("Contributors") {
            switch viewModel.contributorsState {
            case .loading:
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            case .loaded(let contributors):
                contributorRows(contributors)
            case .showingCached(let contributors, let savedAt):
                Label(
                    "Cached · \(savedAt.formatted(.relative(presentation: .named)))",
                    systemImage: "clock.arrow.circlepath"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                contributorRows(contributors)
            case .empty:
                Text("No contributors yet.")
                    .foregroundStyle(.secondary)
            case .rateLimited(let resetAt):
                RateLimitBanner(resetAt: resetAt) {
                    Task { await viewModel.loadContributors() }
                }
            case .failed:
                Button {
                    Task { await viewModel.loadContributors() }
                } label: {
                    Label("Couldn't load contributors — tap to retry", systemImage: "arrow.clockwise")
                        .font(.footnote)
                }
            }
        }
    }

    func contributorRows(_ contributors: [Contributor]) -> some View {
        ForEach(contributors) { contributor in
            HStack(spacing: 12) {
                AsyncImage(url: contributor.avatarURL) { image in
                    image.resizable()
                } placeholder: {
                    Color(.secondarySystemFill)
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())

                Text(contributor.login)
                    .font(.subheadline)

                Spacer()

                Text("\(contributor.contributions.formatted()) commits")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
