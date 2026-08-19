//
//  DetailViewModel.swift
//  RepoExplorer
//
//  Created by Kaan Yeyrek on 19.08.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class DetailViewModel {
    enum ContributorsState: Equatable {
        case loading
        case loaded([Contributor])
        case showingCached([Contributor], savedAt: Date)
        case empty
        case rateLimited(resetAt: Date?)
        case failed
    }

    let repository: Repository
    private(set) var contributorsState: ContributorsState = .loading

    private let api: any GitHubAPIServing
    private let cache: DiskCache

    init(repository: Repository, api: any GitHubAPIServing, cache: DiskCache) {
        self.repository = repository
        self.api = api
        self.cache = cache
    }

    func loadContributors() async {
        let cacheKey = CacheKey.contributors(repositoryID: repository.id)
        do {
            let contributors = try await api.contributors(
                ownerLogin: repository.owner.login,
                repoName: repository.name
            )
            guard !Task.isCancelled else { return }
            contributorsState = contributors.isEmpty ? .empty : .loaded(contributors)
            if !contributors.isEmpty {
                await cache.save(contributors, key: cacheKey)
            }
        } catch is CancellationError {
            return
        } catch APIError.rateLimited(let resetAt) {
            guard !Task.isCancelled else { return }
            if let cached = await cache.load([Contributor].self, key: cacheKey) {
                contributorsState = .showingCached(cached.payload, savedAt: cached.savedAt)
            } else {
                contributorsState = .rateLimited(resetAt: resetAt)
            }
        } catch {
            guard !Task.isCancelled else { return }
            if let cached = await cache.load([Contributor].self, key: cacheKey) {
                contributorsState = .showingCached(cached.payload, savedAt: cached.savedAt)
            } else {
                contributorsState = .failed
            }
        }
    }
}
