//
//  ErrorBanner.swift
//  RepoExplorer
//
//  Created by Kaan Yeyrek on 19.08.2026.
//

import SwiftUI

struct ErrorBanner: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
            Text(message)
                .lineLimit(1)
            Button("Retry", action: onRetry)
                .buttonStyle(.borderless)
        }
        .font(.footnote)
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(.red.opacity(0.12))
    }
}
