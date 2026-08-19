//
//  GitHubAPIClientTests.swift
//  RepoExplorerTests
//
//  Created by Kaan Yeyrek on 19.08.2026.
//

import Foundation
import Testing
@testable import RepoExplorer

@Suite(.serialized)
struct GitHubAPIClientTests {
    private func makeClient() -> GitHubAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return GitHubAPIClient(session: URLSession(configuration: configuration))
    }

    private func response(status: Int, headers: [String: String] = [:], url: URL) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers)!
    }

    @Test func rateLimitedForbiddenMapsToTypedErrorWithResetDate() async throws {
        MockURLProtocol.handler = { request in
            let headers = ["x-ratelimit-remaining": "0", "x-ratelimit-reset": "1787000000"]
            return (self.response(status: 403, headers: headers, url: request.url!), Data())
        }
        do {
            _ = try await makeClient().searchRepositories(query: "swift", page: 1)
            Issue.record("Expected APIError.rateLimited")
        } catch let APIError.rateLimited(resetAt) {
            #expect(resetAt == Date(timeIntervalSince1970: 1_787_000_000))
        }
    }

    @Test func plainForbiddenIsNotMisreadAsRateLimit() async throws {
        MockURLProtocol.handler = { request in
            let headers = ["x-ratelimit-remaining": "41"]
            return (self.response(status: 403, headers: headers, url: request.url!), Data())
        }
        do {
            _ = try await makeClient().searchRepositories(query: "swift", page: 1)
            Issue.record("Expected APIError.http")
        } catch let APIError.http(statusCode) {
            #expect(statusCode == 403)
        }
    }

    @Test func retryAfterHeaderProducesNearFutureResetDate() async throws {
        MockURLProtocol.handler = { request in
            let headers = ["retry-after": "30"]
            return (self.response(status: 429, headers: headers, url: request.url!), Data())
        }
        do {
            _ = try await makeClient().searchRepositories(query: "swift", page: 1)
            Issue.record("Expected APIError.rateLimited")
        } catch let APIError.rateLimited(resetAt) {
            let seconds = try #require(resetAt).timeIntervalSinceNow
            #expect(seconds > 25 && seconds <= 31)
        }
    }

    @Test func emptyRepositoryContributorsDecodeAsEmptyList() async throws {
        MockURLProtocol.handler = { request in
            (self.response(status: 204, url: request.url!), Data())
        }
        let contributors = try await makeClient().contributors(ownerLogin: "owner", repoName: "empty")
        #expect(contributors.isEmpty)
    }

    @Test func connectionLossMapsToOffline() async throws {
        MockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }
        do {
            _ = try await makeClient().searchRepositories(query: "swift", page: 1)
            Issue.record("Expected APIError.offline")
        } catch let error as APIError {
            guard case .offline = error else {
                Issue.record("Expected .offline, got \(error)")
                return
            }
        }
    }

    @Test func searchResponseToleratesNullDescriptionAndLanguage() async throws {
        let json = """
        {"total_count": 1, "incomplete_results": false, "items": [
          {"id": 7, "name": "swift", "full_name": "apple/swift",
           "owner": {"login": "apple", "avatar_url": "https://example.com/a.png"},
           "description": null, "stargazers_count": 10, "open_issues_count": 2,
           "language": null, "html_url": "https://github.com/apple/swift"}
        ]}
        """
        MockURLProtocol.handler = { request in
            (self.response(status: 200, url: request.url!), Data(json.utf8))
        }
        let result = try await makeClient().searchRepositories(query: "swift", page: 1)
        #expect(result.totalCount == 1)
        #expect(result.items.first?.description == nil)
        #expect(result.items.first?.language == nil)
    }
}
