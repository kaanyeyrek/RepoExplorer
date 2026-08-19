//
//  BookmarksView.swift
//  RepoExplorer
//
//  Created by Kaan Yeyrek on 19.08.2026.
//

import SwiftUI

struct BookmarksView: View {
    @Environment(BookmarkStore.self) private var bookmarks

    var body: some View {
        content
            .navigationTitle("Bookmarks")
    }
}

private extension BookmarksView {
    @ViewBuilder
    var content: some View {
        if bookmarks.bookmarks.isEmpty {
            ContentUnavailableView(
                "No bookmarks yet",
                systemImage: "bookmark",
                description: Text("Repositories you bookmark will appear here and stay available offline.")
            )
        } else {
            List(bookmarks.bookmarks) { repository in
                NavigationLink(value: repository) {
                    RepoRow(repository: repository)
                }
            }
            .listStyle(.plain)
        }
    }
}

#Preview {
    NavigationStack {
        BookmarksView()
    }
    .environment(BookmarkStore())
}
