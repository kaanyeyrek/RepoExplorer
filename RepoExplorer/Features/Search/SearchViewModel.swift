//
//  SearchViewModel.swift
//  RepoExplorer
//
//  Created by Kaan Yeyrek on 18.08.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case showingCached(savedAt: Date)
        case rateLimited(resetAt: Date?)
        case failed(message: String)
    }

    enum PaginationState: Equatable {
        case idle
        case loading
        case rateLimited(resetAt: Date?)
        case failed
    }

    static let searchResultCap = 1_000

    var query = ""
    private(set) var repositories: [Repository] = []
    private(set) var phase: Phase = .idle
    private(set) var pagination: PaginationState = .idle

    private var activeQuery: String?
    private var currentPage = 1
    private var reachableResultCount = 0

    private let api: any GitHubAPIServing
    private let cache: DiskCache

    init(api: any GitHubAPIServing, cache: DiskCache) {
        self.api = api
        self.cache = cache
    }

    var canLoadMore: Bool {
        phase == .loaded && repositories.count < reachableResultCount
    }

    func restoreLastSearch() async {
        guard query.isEmpty, phase == .idle else { return }
        guard let cached = await cache.load(SearchSnapshot.self, key: CacheKey.lastSearch) else { return }
        repositories = cached.payload.repositories
        phase = .showingCached(savedAt: cached.savedAt)
        query = cached.payload.query
    }

    func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            repositories = []
            phase = .idle
            pagination = .idle
            activeQuery = nil
            return
        }

        phase = .loading
        pagination = .idle
        do {
            let response = try await api.searchRepositories(query: trimmed, page: 1)
            guard !Task.isCancelled else { return }
            repositories = deduplicated(response.items)
            activeQuery = trimmed
            currentPage = 1
            reachableResultCount = min(response.totalCount, Self.searchResultCap)
            phase = repositories.isEmpty ? .empty : .loaded
            await persistSnapshot(query: trimmed)
        } catch is CancellationError {
            return
        } catch let error as APIError {
            guard !Task.isCancelled else { return }
            await recover(from: error)
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failed(message: error.localizedDescription)
        }
    }

    func loadMoreIfNeeded(after repository: Repository) async {
        guard repository.id == repositories.last?.id else { return }
        guard let activeQuery, canLoadMore, pagination != .loading else { return }

        pagination = .loading
        do {
            let response = try await api.searchRepositories(query: activeQuery, page: currentPage + 1)
            guard !Task.isCancelled else { return }
            repositories = deduplicated(response.items, appendingTo: repositories)
            currentPage += 1
            reachableResultCount = min(response.totalCount, Self.searchResultCap)
            pagination = .idle
            await persistSnapshot(query: activeQuery)
        } catch is CancellationError {
            pagination = .idle
        } catch APIError.rateLimited(let resetAt) {
            pagination = .rateLimited(resetAt: resetAt)
        } catch {
            pagination = .failed
        }
    }

    func retryPagination() async {
        pagination = .idle
        guard let last = repositories.last else { return }
        await loadMoreIfNeeded(after: last)
    }
}

private extension SearchViewModel {
    func recover(from error: APIError) async {
        switch error {
        case .rateLimited(let resetAt):
            phase = .rateLimited(resetAt: resetAt)
        case .offline:
            if let cached = await cache.load(SearchSnapshot.self, key: CacheKey.lastSearch) {
                repositories = cached.payload.repositories
                phase = .showingCached(savedAt: cached.savedAt)
            } else {
                phase = .failed(message: error.localizedDescription)
            }
        default:
            phase = .failed(message: error.localizedDescription)
        }
    }

    func persistSnapshot(query: String) async {
        guard !repositories.isEmpty else { return }
        await cache.save(SearchSnapshot(query: query, repositories: repositories), key: CacheKey.lastSearch)
    }

    func deduplicated(_ new: [Repository], appendingTo existing: [Repository] = []) -> [Repository] {
        var seenIDs = Set(existing.map(\.id))
        var result = existing
        for repository in new where seenIDs.insert(repository.id).inserted {
            result.append(repository)
        }
        return result
    }
}
