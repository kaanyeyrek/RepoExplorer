//
//  RepoExplorerApp.swift
//  RepoExplorer
//
//  Created by Kaan Yeyrek on 18.08.2026.
//

import SwiftUI

@main
struct RepoExplorerApp: App {
    @State private var bookmarkStore = BookmarkStore()

    private let api = GitHubAPIClient()
    private let cache = DiskCache()

    var body: some Scene {
        WindowGroup {
            RootView(api: api, cache: cache)
                .environment(bookmarkStore)
        }
    }
}
