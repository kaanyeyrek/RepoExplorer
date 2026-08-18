//
//  RetryButton.swift
//  RepoExplorer
//
//  Created by Kaan Yeyrek on 19.08.2026.
//

import SwiftUI

struct RetryButton: View {
    let resetAt: Date?
    let onRetry: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let remaining = remainingSeconds(at: context.date), remaining > 0 {
                Text("Try again in \(remaining)s")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Button("Try again", action: onRetry)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func remainingSeconds(at date: Date) -> Int? {
        guard let resetAt else { return nil }
        return max(0, Int(resetAt.timeIntervalSince(date).rounded(.up)))
    }
}
