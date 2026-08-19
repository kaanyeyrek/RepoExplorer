//
//  RepoRow.swift
//  RepoExplorer
//
//  Created by Kaan Yeyrek on 19.08.2026.
//

import SwiftUI

struct RepoRow: View {
    @Environment(BookmarkStore.self) private var bookmarks

    let repository: Repository

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: repository.owner.avatarURL) { image in
                image.resizable()
            } placeholder: {
                Color(.secondarySystemFill)
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(repository.name)
                    .font(.headline)
                Text(repository.owner.login)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let description = repository.description {
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 12) {
                    Label(repository.stars.formatted(.number.notation(.compactName)), systemImage: "star")
                    if let language = repository.language {
                        Text(language)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                bookmarks.toggle(repository)
            } label: {
                Image(systemName: bookmarks.isBookmarked(repository) ? "bookmark.fill" : "bookmark")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(bookmarks.isBookmarked(repository) ? "Remove bookmark" : "Add bookmark")
        }
    }
}

#Preview {
    List {
        RepoRow(repository: Repository(
            id: 1,
            name: "swift",
            fullName: "apple/swift",
            owner: Owner(login: "apple", avatarURL: URL(string: "https://avatars.githubusercontent.com/u/10639145")!),
            description: "The Swift Programming Language",
            stars: 68_500,
            openIssues: 7_200,
            language: "C++",
            htmlURL: URL(string: "https://github.com/apple/swift")!
        ))
    }
    .environment(BookmarkStore())
}
