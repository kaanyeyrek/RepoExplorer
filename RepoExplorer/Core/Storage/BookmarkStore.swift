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
    private static let schemaVersion = 1

    private(set) var bookmarks: [Repository] = []

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: Self.storageKey),
              let envelope = try? JSONDecoder().decode(CacheEnvelope<[Repository]>.self, from: data),
              envelope.version == Self.schemaVersion else { return }
        bookmarks = envelope.payload
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
        let envelope = CacheEnvelope(version: Self.schemaVersion, savedAt: .now, payload: bookmarks)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
