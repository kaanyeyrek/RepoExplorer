//
//  DiskCache.swift
//  RepoExplorer
//
//  Created by Kaan Yeyrek on 18.08.2026.
//

import Foundation

struct CacheEnvelope<Payload: Codable>: Codable {
    let version: Int
    let savedAt: Date
    let payload: Payload
}

actor DiskCache {
    static let schemaVersion = 1

    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directoryName: String = "RepoExplorerCache") {
        directory = URL.cachesDirectory.appending(path: directoryName, directoryHint: .isDirectory)
    }

    func save<T: Codable>(_ payload: T, key: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let envelope = CacheEnvelope(version: Self.schemaVersion, savedAt: .now, payload: payload)
            let data = try encoder.encode(envelope)
            try data.write(to: fileURL(for: key), options: .atomic)
        } catch {
            return
        }
    }

    func load<T: Codable>(_ type: T.Type, key: String) -> CacheEnvelope<T>? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let envelope = try? decoder.decode(CacheEnvelope<T>.self, from: data),
              envelope.version == Self.schemaVersion else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return envelope
    }
}

private extension DiskCache {
    func fileURL(for key: String) -> URL {
        let safeKey = key
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "-")
        return directory.appending(path: safeKey + ".json")
    }
}
