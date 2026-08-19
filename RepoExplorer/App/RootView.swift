//
//  RootView.swift
//  RepoExplorer
//
//  Created by Kaan Yeyrek on 18.08.2026.
//

import SwiftUI

struct RootView: View {
    let api: GitHubAPIClient
    let cache: DiskCache

    var body: some View {
        TabView {
            NavigationStack {
                SearchView(api: api, cache: cache)
                    .navigationDestination(for: Repository.self) { repository in
                        DetailView(repository: repository, api: api, cache: cache)
                    }
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }

            NavigationStack {
                Text("Bookmarks")
            }
            .tabItem { Label("Bookmarks", systemImage: "bookmark") }
        }
    }
}

#Preview {
    RootView(api: GitHubAPIClient(), cache: DiskCache())
        .environment(BookmarkStore())
}
