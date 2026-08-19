//
//  DetailViewModelTests.swift
//  RepoExplorerTests
//
//  Created by Kaan Yeyrek on 19.08.2026.
//

import Foundation
import Testing
@testable import RepoExplorer

@MainActor
struct DetailViewModelTests {
    private func makeCache() -> DiskCache {
        DiskCache(directoryName: "tests-detail-\(UUID().uuidString)")
    }

    private func makeViewModel(
        cache: DiskCache,
        contributors: @escaping @Sendable (String, String) async throws -> [Contributor]
    ) -> DetailViewModel {
        DetailViewModel(
            repository: TestData.repo(id: 7),
            api: StubAPI(contributors: contributors),
            cache: cache
        )
    }

    private func contributor(id: Int) -> Contributor {
        Contributor(
            id: id,
            login: "user\(id)",
            avatarURL: URL(string: "https://example.com/a.png")!,
            contributions: id
        )
    }

    @Test func successfulLoadShowsContributors() async {
        let expected = [contributor(id: 1), contributor(id: 2)]
        let viewModel = makeViewModel(cache: makeCache()) { _, _ in expected }

        await viewModel.loadContributors()

        #expect(viewModel.contributorsState == .loaded(expected))
    }

    @Test func emptyContributorsShowEmptyState() async {
        let viewModel = makeViewModel(cache: makeCache()) { _, _ in [] }

        await viewModel.loadContributors()

        #expect(viewModel.contributorsState == .empty)
    }

    @Test func rateLimitWithCacheFallsBackToCachedContributors() async {
        let cache = makeCache()
        let cached = [contributor(id: 5)]
        await cache.save(cached, key: CacheKey.contributors(repositoryID: 7))
        let viewModel = makeViewModel(cache: cache) { _, _ in
            throw APIError.rateLimited(resetAt: nil)
        }

        await viewModel.loadContributors()

        guard case .showingCached(let contributors, _) = viewModel.contributorsState else {
            Issue.record("Expected .showingCached, got \(viewModel.contributorsState)")
            return
        }
        #expect(contributors == cached)
    }

    @Test func rateLimitWithoutCacheExposesResetDate() async {
        let reset = Date(timeIntervalSinceNow: 30)
        let viewModel = makeViewModel(cache: makeCache()) { _, _ in
            throw APIError.rateLimited(resetAt: reset)
        }

        await viewModel.loadContributors()

        #expect(viewModel.contributorsState == .rateLimited(resetAt: reset))
    }
}
