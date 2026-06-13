//
//  SessionGateSheet.swift
//  meditation-app-ios
//

import SwiftUI
import AuthenticationServices

/// Auth sheet used both as a free-trial gate and as a direct sign-in/sign-up entry point.
struct SessionGateSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// Called after a successful sign-in or sign-up.
    let onAuthenticated: () -> Void
    /// When `true`, hide the "Not now" button (used when the user navigates here intentionally).
    let showNotNow: Bool

    @State private var isSignUp: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(onAuthenticated: @escaping () -> Void, startInSignUp: Bool = false, showNotNow: Bool = true) {
        self.onAuthenticated = onAuthenticated
        self.showNotNow = showNotNow
        self._isSignUp = State(initialValue: startInSignUp)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                emailPasswordSection
                orDivider
                socialAuthSection
                toggleModeButton
                notNowButton
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appThemedScreen()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var socialAuthSection: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(.signIn, onRequest: { request in
                request.requestedScopes = [.fullName, .email]
            }, onCompletion: handleAppleSignIn)
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button(action: handleGoogleSignIn) {
                HStack(spacing: 10) {
                    Image(systemName: "globe")
                        .font(.system(size: 18, weight: .medium))
                    Text("Continue with Google")
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(AppTheme.heroTitle)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
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

    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(AppTheme.cardStroke)
                .frame(height: 1)
            Text("or")
                .font(.caption)
                .foregroundStyle(AppTheme.bodyMuted)
            Rectangle()
                .fill(AppTheme.cardStroke)
                .frame(height: 1)
        }
    }

    private var emailPasswordSection: some View {
        VStack(spacing: 12) {
            inputField(label: "Email") {
                TextField("you@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            inputField(label: "Password") {
                SecureField("Password", text: $password)
                    .textContentType(isSignUp ? .newPassword : .password)
            }

            if isSignUp {
                inputField(label: "Confirm password") {
                    SecureField("Confirm password", text: $confirmPassword)
                        .textContentType(.newPassword)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let message = errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: handleEmailAuth) {
                ZStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(AppTheme.heroTitle)
                    } else {
                        Text(isSignUp ? "Sign up" : "Log in")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.heroTitle)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
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
            .disabled(isLoading)
        }
    }

    @ViewBuilder
    private func inputField<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.rowLabel)
            content()
                .foregroundStyle(AppTheme.rowValue)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
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
    }

    private var toggleModeButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isSignUp.toggle()
                errorMessage = nil
            }
        } label: {
            Text(isSignUp
                 ? "Already have an account? Log in"
                 : "Don't have an account? Sign up")
                .font(.footnote)
                .foregroundStyle(AppTheme.bodyMuted)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var notNowButton: some View {
        if showNotNow {
            Button("Not now") {
                dismiss()
            }
            .font(.body)
            .foregroundStyle(AppTheme.bodyMuted)
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    // MARK: - Auth handlers

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard auth.credential is ASAuthorizationAppleIDCredential else { return }
            // TODO: forward identityToken to backend for server-side verification
            completeAuthentication()
        case .failure(let error):
            let nsError = error as NSError
            guard nsError.code != ASAuthorizationError.canceled.rawValue else { return }
            errorMessage = "Apple Sign In failed. Please try again."
        }
    }

    private func handleGoogleSignIn() {
        // TODO: Configure Google OAuth 2.0:
        //   1. Create a project in Google Cloud Console and generate an iOS OAuth client ID.
        //   2. Add the reversed client ID as a URL scheme in the project's Info.plist.
        //   3. Replace this stub with an ASWebAuthenticationSession flow using that client ID.
        errorMessage = "Google Sign In is not configured yet."
    }

    private func handleEmailAuth() {
        errorMessage = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }
        if isSignUp {
            guard password == confirmPassword else {
                errorMessage = "Passwords do not match."
                return
            }
            guard password.count >= 8 else {
                errorMessage = "Password must be at least 8 characters."
                return
            }
        }

        isLoading = true
        // TODO: replace with real backend auth call (POST /login or /signup)
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            await MainActor.run {
                isLoading = false
                completeAuthentication()
            }
        }
    }

    private func completeAuthentication() {
        SessionUsageStore.shared.setAuthenticated(true)
        onAuthenticated()
    }
}

#Preview("Gate (trial expired)") {
    SessionGateSheet(onAuthenticated: {})
}

#Preview("Sign up") {
    SessionGateSheet(onAuthenticated: {}, startInSignUp: true, showNotNow: false)
}
