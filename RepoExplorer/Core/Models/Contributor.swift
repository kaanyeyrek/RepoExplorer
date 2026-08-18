//
//  Contributor.swift
//  RepoExplorer
//
//  Created by Kaan Yeyrek on 18.08.2026.
//

import Foundation

struct Contributor: Identifiable, Hashable, Codable {
    let id: Int
    let login: String
    let avatarURL: URL
    let contributions: Int

    enum CodingKeys: String, CodingKey {
        case id
        case login
        case contributions
        case avatarURL = "avatar_url"
    }
}
