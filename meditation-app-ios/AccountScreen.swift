//
//  AccountScreen.swift
//  meditation-app-ios
//
//  Created by Matt Pinchover on 5/23/26.
//

import SwiftUI

struct AccountScreen: View {
    @ObservedObject private var usageStore = SessionUsageStore.shared

    var body: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 0)

            if usageStore.isAuthenticated {
                authenticatedContent
            } else {
                unauthenticatedContent
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appThemedScreen()
        .navigationTextBackButton()
    }

    private var authenticatedContent: some View {
        VStack(spacing: 20) {
            Text("Account")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.heroTitle)

            usageStat

            Button {
                SessionUsageStore.shared.setAuthenticated(false)
            } label: {
                Text("Log out")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.heroTitle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.cardFill)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(AppTheme.cardStroke, lineWidth: 1)
                            }
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private var unauthenticatedContent: some View {
        VStack(spacing: 12) {
            Text("Not signed in")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.heroTitle)

            usageStat
        }
    }

    private var usageStat: some View {
        VStack(spacing: 6) {
            Text("Trial time used")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.rowLabel)
            Text(ElapsedFormat.sessionCountdown(usageStore.totalCompletedSeconds))
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.rowValue)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.cardFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(AppTheme.cardStroke, lineWidth: 1)
                }
        }
    }
}

#Preview {
    NavigationStack {
        AccountScreen()
    }
}
