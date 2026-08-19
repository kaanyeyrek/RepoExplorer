//
//  TestData.swift
//  RepoExplorerTests
//
//  Created by Kaan Yeyrek on 19.08.2026.
//

import Foundation
@testable import RepoExplorer

enum TestData {
    static func repo(id: Int, name: String = "repo") -> Repository {
        Repository(
            id: id,
            name: name,
            fullName: "owner/\(name)",
            owner: Owner(login: "owner", avatarURL: URL(string: "https://example.com/avatar.png")!),
            description: nil,
            stars: 1,
            openIssues: 0,
            language: nil,
            htmlURL: URL(string: "https://example.com")!
        )
    }

    static func page(_ repositories: [Repository], total: Int) -> SearchResponse {
        SearchResponse(totalCount: total, incompleteResults: false, items: repositories)
    }
}

struct StubAPI: GitHubAPIServing {
    var search: @Sendable (String, Int) async throws -> SearchResponse
    var contributorsResult: @Sendable (String, String) async throws -> [Contributor]

    init(
        search: @escaping @Sendable (String, Int) async throws -> SearchResponse = { _, _ in TestData.page([], total: 0) },
        contributors: @escaping @Sendable (String, String) async throws -> [Contributor] = { _, _ in [] }
    ) {
        self.search = search
        self.contributorsResult = contributors
    }

    func searchRepositories(query: String, page: Int) async throws -> SearchResponse {
        try await search(query, page)
    }

    func contributors(ownerLogin: String, repoName: String) async throws -> [Contributor] {
        try await contributorsResult(ownerLogin, repoName)
    }
}

actor CallCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}
