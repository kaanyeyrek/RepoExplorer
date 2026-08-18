//
//  Repository.swift
//  RepoExplorer
//
//  Created by Kaan Yeyrek on 18.08.2026.
//

import Foundation

struct Repository: Identifiable, Hashable, Codable {
    let id: Int
    let name: String
    let fullName: String
    let owner: Owner
    let description: String?
    let stars: Int
    let openIssues: Int
    let language: String?
    let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case owner
        case description
        case language
        case fullName = "full_name"
        case stars = "stargazers_count"
        case openIssues = "open_issues_count"
        case htmlURL = "html_url"
    }
}
