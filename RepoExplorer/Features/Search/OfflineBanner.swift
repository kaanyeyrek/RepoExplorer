//
//  OfflineBanner.swift
//  RepoExplorer
//
//  Created by Kaan Yeyrek on 19.08.2026.
//

import SwiftUI

struct OfflineBanner: View {
    let savedAt: Date
    let query: String

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            Label(
                "Saved “\(query)” results · \(savedAt.formatted(.relative(presentation: .named)))",
                systemImage: "clock.arrow.circlepath"
            )
            .font(.footnote)
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(.orange.opacity(0.15))
        }
    }
}
