//
//  BookmarkStore.swift
//  RepoExplorer
//
//  Created by Kaan Yeyrek on 18.08.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class BookmarkStore {
    private static let storageKey = "bookmarkedRepositories"

    private(set) var bookmarks: [Repository] = []

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([Repository].self, from: data) else { return }
        bookmarks = decoded
    }

    func isBookmarked(_ repository: Repository) -> Bool {
        bookmarks.contains { $0.id == repository.id }
    }

    func toggle(_ repository: Repository) {
        if let index = bookmarks.firstIndex(where: { $0.id == repository.id }) {
            bookmarks.remove(at: index)
        } else {
            bookmarks.append(repository)
        }
        persist()
    }
}

private extension BookmarkStore {
    func persist() {
        guard let data = try? JSONEncoder().encode(bookmarks) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
