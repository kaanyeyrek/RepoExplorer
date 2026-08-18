//
//  RootView.swift
//  RepoExplorer
//
//  Created by Kaan Yeyrek on 18.08.2026.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Text("Search")
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            Text("Bookmarks")
                .tabItem { Label("Bookmarks", systemImage: "bookmark") }
        }
    }
}

#Preview {
    RootView()
}
