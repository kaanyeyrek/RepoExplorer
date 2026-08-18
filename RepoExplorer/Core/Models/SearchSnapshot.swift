//
//  SearchSnapshot.swift
//  RepoExplorer
//
//  Created by Kaan Yeyrek on 18.08.2026.
//

import Foundation

struct SearchSnapshot: Codable {
    let query: String
    let repositories: [Repository]
}
