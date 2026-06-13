//
//  AccountScreen.swift
//  meditation-app-ios
//
//  Created by Matt Pinchover on 5/23/26.
//

import SwiftUI

struct AccountScreen: View {
    @ObservedObject private var usageStore = SessionUsageStore.shared
    @State private var showSignIn = false
    @State private var showSignUp = false

    var body: some View {
        Group {
            if usageStore.isAuthenticated {
                authenticatedContent
            } else {
                unauthenticatedContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appThemedScreen()
        .navigationTextBackButton()
        .sheet(isPresented: $showSignIn) {
            SessionGateSheet(onAuthenticated: {
                showSignIn = false
            }, startInSignUp: false, showNotNow: false)
        }
        .sheet(isPresented: $showSignUp) {
            SessionGateSheet(onAuthenticated: {
                showSignUp = false
            }, startInSignUp: true, showNotNow: false)
        }
    }

    // MARK: - Unauthenticated

    private var unauthenticatedContent: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            authButton(title: "Sign in") { showSignIn = true }
            authButton(title: "Sign up") { showSignUp = true }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Authenticated

    private var authenticatedContent: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            usageStat
            authButton(title: "Log out") {
                SessionUsageStore.shared.setAuthenticated(false)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Shared

    private func authButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
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
