//
//  SearchViewModelTests.swift
//  RepoExplorerTests
//
//  Created by Kaan Yeyrek on 19.08.2026.
//

import Foundation
import Testing
@testable import RepoExplorer

@MainActor
struct SearchViewModelTests {
    private func makeCache() -> DiskCache {
        DiskCache(directoryName: "tests-\(UUID().uuidString)")
    }

    @Test func pagesAreDeduplicatedByRepositoryID() async {
        let stub = StubAPI(search: { _, page in
            page == 1
                ? TestData.page([1, 2, 3].map { TestData.repo(id: $0) }, total: 5)
                : TestData.page([3, 4].map { TestData.repo(id: $0) }, total: 5)
        })
        let viewModel = SearchViewModel(api: stub, cache: makeCache())
        viewModel.query = "swift"

        await viewModel.runSearch()
        await viewModel.loadMoreIfNeeded(after: viewModel.repositories.last!)

        #expect(viewModel.repositories.map(\.id) == [1, 2, 3, 4])
    }

    @Test func loadMoreStopsAtGitHubSearchCeiling() async {
        let stub = StubAPI(search: { _, _ in
            TestData.page((1...1_000).map { TestData.repo(id: $0) }, total: 2_000)
        })
        let viewModel = SearchViewModel(api: stub, cache: makeCache())
        viewModel.query = "swift"

        await viewModel.runSearch()

        #expect(viewModel.repositories.count == 1_000)
        #expect(viewModel.canLoadMore == false)
    }

    @Test func blankQueryNeverHitsTheAPI() async {
        let counter = CallCounter()
        let stub = StubAPI(search: { _, _ in
            await counter.increment()
            return TestData.page([], total: 0)
        })
        let viewModel = SearchViewModel(api: stub, cache: makeCache())
        viewModel.query = "   "

        await viewModel.runSearch()

        #expect(viewModel.phase == .idle)
        #expect(await counter.count == 0)
    }

    @Test func rateLimitedSearchExposesResetDate() async {
        let reset = Date(timeIntervalSinceNow: 42)
        let stub = StubAPI(search: { _, _ in
            throw APIError.rateLimited(resetAt: reset)
        })
        let viewModel = SearchViewModel(api: stub, cache: makeCache())
        viewModel.query = "swift"

        await viewModel.runSearch()

        #expect(viewModel.phase == .rateLimited(resetAt: reset))
    }

    @Test func offlineSearchFallsBackToCachedSnapshot() async {
        let cache = makeCache()
        await cache.save(
            SearchSnapshot(query: "swift", repositories: [TestData.repo(id: 7)]),
            key: CacheKey.lastSearch
        )
        let stub = StubAPI(search: { _, _ in
            throw APIError.offline
        })
        let viewModel = SearchViewModel(api: stub, cache: cache)
        viewModel.query = "swift"

        await viewModel.runSearch()

        #expect(viewModel.repositories.map(\.id) == [7])
        guard case .showingCached = viewModel.phase else {
            Issue.record("Expected .showingCached, got \(viewModel.phase)")
            return
        }
    }

    @Test func returningToLoadedSearchDoesNotRefetch() async {
        let counter = CallCounter()
        let stub = StubAPI(search: { _, _ in
            await counter.increment()
            return TestData.page([TestData.repo(id: 1)], total: 1)
        })
        let viewModel = SearchViewModel(api: stub, cache: makeCache())
        viewModel.query = "swift"

        await viewModel.runSearch()
        await viewModel.runSearch()

        #expect(await counter.count == 1)
    }

    @Test func stalePaginationResponseIsDropped() async {
        let stub = StubAPI(search: { query, page in
            if query == "old", page == 2 {
                try? await Task.sleep(for: .milliseconds(80))
                return TestData.page([TestData.repo(id: 99)], total: 40)
            }
            if query == "old" {
                return TestData.page([1, 2, 3].map { TestData.repo(id: $0) }, total: 40)
            }
            return TestData.page([10, 11].map { TestData.repo(id: $0) }, total: 2)
        })
        let viewModel = SearchViewModel(api: stub, cache: makeCache())
        viewModel.query = "old"
        await viewModel.runSearch()

        let pagination = Task { await viewModel.loadMoreIfNeeded(after: viewModel.repositories.last!) }
        try? await Task.sleep(for: .milliseconds(20))
        viewModel.query = "new"
        await viewModel.runSearch()
        await pagination.value

        #expect(viewModel.repositories.map(\.id) == [10, 11])
        #expect(viewModel.pagination == .idle)
    }
}
