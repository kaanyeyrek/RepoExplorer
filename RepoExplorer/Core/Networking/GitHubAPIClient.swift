//
//  GitHubAPIClient.swift
//  RepoExplorer
//
//  Created by Kaan Yeyrek on 18.08.2026.
//

import Foundation

protocol GitHubAPIServing: Sendable {
    func searchRepositories(query: String, page: Int) async throws -> SearchResponse
    func contributors(ownerLogin: String, repoName: String) async throws -> [Contributor]
}

struct GitHubAPIClient: GitHubAPIServing {
    static let pageSize = 30

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let token = ProcessInfo.processInfo.environment["GITHUB_TOKEN"]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchRepositories(query: String, page: Int) async throws -> SearchResponse {
        var components = URLComponents(string: "https://api.github.com/search/repositories")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(Self.pageSize))
        ]
        guard let url = components?.url else { throw APIError.invalidURL }
        let (data, _) = try await perform(url: url)
        return try decode(SearchResponse.self, from: data)
    }

    func contributors(ownerLogin: String, repoName: String) async throws -> [Contributor] {
        var components = URLComponents(string: "https://api.github.com/repos/\(ownerLogin)/\(repoName)/contributors")
        components?.queryItems = [URLQueryItem(name: "per_page", value: String(Self.pageSize))]
        guard let url = components?.url else { throw APIError.invalidURL }
        let (data, response) = try await perform(url: url)
        guard response.statusCode != 204 else { return [] }
        return try decode([Contributor].self, from: data)
    }
}

private extension GitHubAPIClient {
    func perform(url: URL) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw mapTransportError(urlError)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport(underlying: URLError(.badServerResponse))
        }
        try validate(http)
        return (data, http)
    }

    func validate(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 403, 429:
            if isRateLimited(response) {
                throw APIError.rateLimited(resetAt: resetDate(from: response))
            }
            throw APIError.http(statusCode: response.statusCode)
        default:
            throw APIError.http(statusCode: response.statusCode)
        }
    }

    func isRateLimited(_ response: HTTPURLResponse) -> Bool {
        response.value(forHTTPHeaderField: "x-ratelimit-remaining") == "0"
            || response.value(forHTTPHeaderField: "retry-after") != nil
    }

    func resetDate(from response: HTTPURLResponse) -> Date? {
        if let retryAfterSeconds = response.value(forHTTPHeaderField: "retry-after").flatMap(TimeInterval.init) {
            return Date.now.addingTimeInterval(retryAfterSeconds)
        }
        if let resetEpoch = response.value(forHTTPHeaderField: "x-ratelimit-reset").flatMap(TimeInterval.init) {
            return Date(timeIntervalSince1970: resetEpoch)
        }
        return nil
    }

    func mapTransportError(_ urlError: URLError) -> Error {
        switch urlError.code {
        case .cancelled:
            return CancellationError()
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return APIError.offline
        default:
            return APIError.transport(underlying: urlError)
        }
    }

    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.decoding(underlying: error)
        }
    }
}
