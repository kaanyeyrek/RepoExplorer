//
//  OfflineBanner.swift
//  RepoExplorer
//
//  Created by Kaan Yeyrek on 19.08.2026.
//

import SwiftUI

struct OfflineBanner: View {
    let savedAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            Label(
                "Offline · showing results from \(savedAt.formatted(.relative(presentation: .named)))",
                systemImage: "wifi.slash"
            )
            .font(.footnote)
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(.orange.opacity(0.15))
        }
    }
}
