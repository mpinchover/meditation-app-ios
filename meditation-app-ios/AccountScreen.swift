//
//  AccountScreen.swift
//  meditation-app-ios
//
//  Created by Matt Pinchover on 5/23/26.
//

import SwiftUI
import FirebaseAuth

struct AccountScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var usageStore = SessionUsageStore.shared
    @State private var showSignIn = false
    @State private var showSignUp = false
    @State private var showDeleteConfirmation = false
    @State private var deleteError: String?

    private var userEmail: String {
        Auth.auth().currentUser?.email ?? ""
    }

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
                dismiss()
            }, startInSignUp: false)
        }
        .sheet(isPresented: $showSignUp) {
            SessionGateSheet(onAuthenticated: {
                showSignUp = false
                dismiss()
            }, startInSignUp: true)
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
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                statRow(label: "Minutes meditated", value: "127")

                TextField("", text: .constant(userEmail))
                    .foregroundStyle(AppTheme.bodyMuted)
                    .disabled(true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppTheme.cardFill)
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(AppTheme.cardStroke, lineWidth: 1)
                            }
                    }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                authButton(title: "Log out") {
                    try? Auth.auth().signOut()
                    SessionUsageStore.shared.setAuthenticated(false)
                }

                authButton(title: "Delete account", textColor: .red) {
                    showDeleteConfirmation = true
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .confirmationDialog("Delete account?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete account", role: .destructive) {
                    deleteAccount()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account and all your data. This cannot be undone.")
            }
            .alert("Couldn't delete account", isPresented: .constant(deleteError != nil)) {
                Button("OK") { deleteError = nil }
            } message: {
                Text(deleteError ?? "")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Shared

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundStyle(AppTheme.secondaryText)
            Spacer(minLength: 12)
            Text(value)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.rowValue)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.cardFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(AppTheme.cardStroke, lineWidth: 1)
                }
        }
    }

    private func authButton(title: String, textColor: Color = AppTheme.heroTitle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(textColor)
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

    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else { return }
        user.delete { error in
            if let error {
                deleteError = error.localizedDescription
            } else {
                try? Auth.auth().signOut()
                SessionUsageStore.shared.setAuthenticated(false)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AccountScreen()
    }
}
