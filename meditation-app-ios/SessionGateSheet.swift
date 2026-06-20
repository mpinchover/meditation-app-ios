//
//  SessionGateSheet.swift
//  meditation-app-ios
//

import SwiftUI
import AuthenticationServices
import CryptoKit
import FirebaseAuth

/// Auth sheet used both as a free-trial gate and as a direct sign-in/sign-up entry point.
struct SessionGateSheet: View {
    /// Called after a successful sign-in or sign-up.
    let onAuthenticated: () -> Void

    @State private var isSignUp: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentNonce: String?
    @State private var googleAuthSession: ASWebAuthenticationSession?
    @State private var googlePresentationContext = GooglePresentationContext()

    init(onAuthenticated: @escaping () -> Void, startInSignUp: Bool = false) {
        self.onAuthenticated = onAuthenticated
        self._isSignUp = State(initialValue: startInSignUp)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                emailPasswordSection
                orDivider
                socialAuthSection
                toggleModeButton
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
                let nonce = makeAppleNonce()
                currentNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = sha256Hex(nonce)
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
                TextField("Email", text: $email)
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

    // MARK: - Auth handlers

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = "Apple Sign In failed. Please try again."
                return
            }
            isLoading = true
            errorMessage = nil
            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: nonce,
                fullName: credential.fullName
            )
            Task { @MainActor in
                do {
                    try await Auth.auth().signIn(with: firebaseCredential)
                    isLoading = false
                    completeAuthentication()
                } catch {
                    isLoading = false
                    errorMessage = "Apple Sign In failed. Please try again."
                }
            }
        case .failure(let error):
            let nsError = error as NSError
            guard nsError.code != ASAuthorizationError.canceled.rawValue else { return }
            errorMessage = "Apple Sign In failed. Please try again."
        }
    }

    // Random nonce for Apple Sign In (alphanumeric charset matching Firebase docs)
    private func makeAppleNonce() -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: 32)
        SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    // SHA-256 as a lowercase hex string — required format for Apple's nonce field
    private func sha256Hex(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    private func handleGoogleSignIn() {
        // Values from GoogleService-Info.plist
        let clientID = "724373166676-5o4tiei3c3jdpsbbq5m8qisdpmaglkfc.apps.googleusercontent.com"
        let callbackScheme = "com.googleusercontent.apps.724373166676-5o4tiei3c3jdpsbbq5m8qisdpmaglkfc"
        let redirectURI = "\(callbackScheme):/"

        let verifier = makePKCEVerifier()
        let challenge = makePKCEChallenge(for: verifier)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        guard let authURL = components.url else { return }

        isLoading = true
        errorMessage = nil

        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: callbackScheme
        ) { callbackURL, error in
            Task { @MainActor in
                googleAuthSession = nil

                if let error {
                    isLoading = false
                    if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                        errorMessage = "Google Sign In failed. Please try again."
                    }
                    return
                }

                guard let callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                          .queryItems?.first(where: { $0.name == "code" })?.value else {
                    isLoading = false
                    errorMessage = "Google Sign In failed. Please try again."
                    return
                }

                do {
                    let (idToken, accessToken) = try await exchangeGoogleCode(
                        code, verifier: verifier, clientID: clientID, redirectURI: redirectURI
                    )
                    let credential = GoogleAuthProvider.credential(
                        withIDToken: idToken, accessToken: accessToken
                    )
                    try await Auth.auth().signIn(with: credential)
                    isLoading = false
                    completeAuthentication()
                } catch {
                    isLoading = false
                    errorMessage = "Google Sign In failed. Please try again."
                }
            }
        }
        session.presentationContextProvider = googlePresentationContext
        session.prefersEphemeralWebBrowserSession = false
        googleAuthSession = session
        session.start()
    }

    private func makePKCEVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func makePKCEChallenge(for verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func exchangeGoogleCode(
        _ code: String, verifier: String, clientID: String, redirectURI: String
    ) async throws -> (idToken: String, accessToken: String) {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let allowed = CharacterSet.urlQueryAllowed
        request.httpBody = [
            "client_id": clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
        ]
        .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? $0.value)" }
        .joined(separator: "&")
        .data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)

        struct TokenResponse: Decodable {
            let id_token: String
            let access_token: String
        }
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        return (decoded.id_token, decoded.access_token)
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

// Provides the window anchor that ASWebAuthenticationSession needs to present the OAuth sheet.
// Stored as @State so SwiftUI keeps it alive across view body re-evaluations.
private final class GooglePresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .compactMap { $0.keyWindow }
            .first ?? ASPresentationAnchor()
    }
}

#Preview("Gate (trial expired)") {
    SessionGateSheet(onAuthenticated: {})
}

#Preview("Sign up") {
    SessionGateSheet(onAuthenticated: {}, startInSignUp: true)
}
