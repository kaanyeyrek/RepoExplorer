//
//  DiskCacheTests.swift
//  RepoExplorerTests
//
//  Created by Kaan Yeyrek on 19.08.2026.
//

import Foundation
import Testing
@testable import RepoExplorer

struct DiskCacheTests {
    @Test func roundTripPreservesPayload() async {
        let cache = DiskCache(directoryName: "tests-roundtrip-\(UUID().uuidString)")

        await cache.save(["alpha", "beta"], key: "list")
        let loaded = await cache.load([String].self, key: "list")

        #expect(loaded?.payload == ["alpha", "beta"])
        #expect(loaded?.version == DiskCache.schemaVersion)
    }

    @Test func corruptedFileIsDiscardedAndCleanedUp() async throws {
        let directoryName = "tests-corrupt-\(UUID().uuidString)"
        let cache = DiskCache(directoryName: directoryName)
        await cache.save(["victim"], key: "victim")

        let fileURL = URL.cachesDirectory
            .appending(path: directoryName)
            .appending(path: "victim.json")
        try Data("definitely not json".utf8).write(to: fileURL)

        let loaded = await cache.load([String].self, key: "victim")

        #expect(loaded == nil)
        #expect(FileManager.default.fileExists(atPath: fileURL.path) == false)
    }

    @Test func outdatedSchemaVersionIsInvalidated() async throws {
        let directoryName = "tests-version-\(UUID().uuidString)"
        let cache = DiskCache(directoryName: directoryName)
        await cache.save(["current"], key: "entry")

        let fileURL = URL.cachesDirectory
            .appending(path: directoryName)
            .appending(path: "entry.json")
        let staleEnvelope = """
        {"version": 999, "savedAt": 0, "payload": ["stale"]}
        """
        try Data(staleEnvelope.utf8).write(to: fileURL)

        let loaded = await cache.load([String].self, key: "entry")

        #expect(loaded == nil)
        #expect(FileManager.default.fileExists(atPath: fileURL.path) == false)
    }
}
