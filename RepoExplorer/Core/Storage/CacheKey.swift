//
//  CacheKey.swift
//  RepoExplorer
//
//  Created by Kaan Yeyrek on 18.08.2026.
//

import Foundation

enum CacheKey {
    static let lastSearch = "last-search"

    static func contributors(repositoryID: Int) -> String {
        "contributors-\(repositoryID)"
    }
}
