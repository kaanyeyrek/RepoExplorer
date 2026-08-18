//
//  RateLimitBanner.swift
//  RepoExplorer
//
//  Created by Kaan Yeyrek on 19.08.2026.
//

import SwiftUI

struct RateLimitBanner: View {
    let resetAt: Date?
    let onRetry: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 8) {
                Image(systemName: "hourglass")
                if let remaining = remainingSeconds(at: context.date), remaining > 0 {
                    Text("Rate limit reached · retry in \(remaining)s")
                } else {
                    Text("Rate limit reached")
                    Button("Retry", action: onRetry)
                        .buttonStyle(.borderless)
                }
            }
            .font(.footnote)
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(.yellow.opacity(0.15))
        }
    }

    private func remainingSeconds(at date: Date) -> Int? {
        guard let resetAt else { return nil }
        return max(0, Int(resetAt.timeIntervalSince(date).rounded(.up)))
    }
}
