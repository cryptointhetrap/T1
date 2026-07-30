import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import Security
import UIKit

@MainActor
final class GoogleAuthManager: NSObject, ObservableObject {
    @Published private(set) var session: GoogleSession?
    @Published var lastError: String?

    private var webAuthSession: ASWebAuthenticationSession?
    private var pendingCodeVerifier: String?

    override init() {
        super.init()
        session = KeychainStore.loadGoogleSession()
    }

    var isConnected: Bool { session != nil }

    func connect() {
        let codeVerifier = Self.generateCodeVerifier()
        pendingCodeVerifier = codeVerifier

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: AppConfig.googleClientID),
            URLQueryItem(name: "redirect_uri", value: AppConfig.googleRedirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: AppConfig.googleCalendarScopes),
            URLQueryItem(name: "code_challenge", value: Self.codeChallenge(for: codeVerifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]
        guard let authorizeURL = components.url else { return }

        let authSession = ASWebAuthenticationSession(
            url: authorizeURL,
            callbackURLScheme: AppConfig.googleRedirectScheme
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                self?.handleCallback(callbackURL: callbackURL, error: error)
            }
        }
        authSession.presentationContextProvider = self
        webAuthSession = authSession
        authSession.start()
    }

    func disconnect() {
        session = nil
        KeychainStore.clearGoogleSession()
    }

    private func handleCallback(callbackURL: URL?, error: Error?) {
        if let error {
            if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                lastError = error.localizedDescription
            }
            return
        }

        guard
            let callbackURL,
            let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "code" })?.value,
            let codeVerifier = pendingCodeVerifier
        else {
            lastError = "Google did not return an authorization code."
            return
        }

        Task { await exchangeCode(code, codeVerifier: codeVerifier) }
    }

    private func exchangeCode(_ code: String, codeVerifier: String) async {
        do {
            let tokens = try await GoogleTokenClient.exchange(code: code, codeVerifier: codeVerifier)
            let newSession = GoogleSession(tokenResponse: tokens)
            KeychainStore.saveGoogleSession(newSession)
            session = newSession
        } catch {
            lastError = "Could not complete Google sign-in: \(error.localizedDescription)"
        }
    }

    /// Returns a valid access token, transparently refreshing it if expired.
    /// Refreshing is also secret-free — same PKCE public-client model.
    func validAccessToken() async throws -> String {
        guard var current = session else {
            throw GoogleCalendarAPIClient.APIError.notAuthenticated
        }

        if current.isExpired {
            guard let refreshToken = current.refreshToken else {
                throw GoogleCalendarAPIClient.APIError.notAuthenticated
            }
            let tokens = try await GoogleTokenClient.refresh(refreshToken: refreshToken)
            current = GoogleSession(tokenResponse: tokens, fallbackRefreshToken: refreshToken)
            KeychainStore.saveGoogleSession(current)
            session = current
        }

        return current.accessToken
    }

    private static func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64URLEncodedString()
    }

    private static func codeChallenge(for verifier: String) -> String {
        let hashed = SHA256.hash(data: Data(verifier.utf8))
        return Data(hashed).base64URLEncodedString()
    }
}

extension GoogleAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
