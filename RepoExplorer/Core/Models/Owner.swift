//
//  Owner.swift
//  RepoExplorer
//
//  Created by Kaan Yeyrek on 18.08.2026.
//

import Foundation

struct Owner: Hashable, Codable {
    let login: String
    let avatarURL: URL

    enum CodingKeys: String, CodingKey {
        case login
        case avatarURL = "avatar_url"
    }
}
