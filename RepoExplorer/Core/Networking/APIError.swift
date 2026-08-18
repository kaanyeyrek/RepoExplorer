//
//  APIError.swift
//  RepoExplorer
//
//  Created by Kaan Yeyrek on 18.08.2026.
//

import Foundation

enum APIError: Error {
    case invalidURL
    case offline
    case rateLimited(resetAt: Date?)
    case http(statusCode: Int)
    case decoding(underlying: Error)
    case transport(underlying: URLError)
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request could not be built."
        case .offline:
            return "You appear to be offline."
        case .rateLimited:
            return "GitHub rate limit reached."
        case .http(let statusCode):
            return "The server responded with an error (\(statusCode))."
        case .decoding:
            return "The response could not be read."
        case .transport:
            return "A network error occurred."
        }
    }
}
