import AuthenticationServices
import Combine
import Foundation
import UIKit

@MainActor
final class StravaAuthManager: NSObject, ObservableObject {
    @Published private(set) var session: StravaSession?
    @Published var lastError: String?

    private var webAuthSession: ASWebAuthenticationSession?

    override init() {
        super.init()
        session = KeychainStore.load()
    }

    var isConnected: Bool { session != nil }

    func connect() {
        var components = URLComponents(string: "https://www.strava.com/oauth/mobile/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: AppConfig.stravaClientID),
            URLQueryItem(name: "redirect_uri", value: AppConfig.oauthRedirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "scope", value: AppConfig.oauthScopes),
        ]
        guard let authorizeURL = components.url else { return }

        let authSession = ASWebAuthenticationSession(
            url: authorizeURL,
            callbackURLScheme: AppConfig.oauthRedirectScheme
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                self?.handleCallback(callbackURL: callbackURL, error: error)
            }
        }
        authSession.presentationContextProvider = self
        authSession.prefersEphemeralWebBrowserSession = false
        webAuthSession = authSession
        authSession.start()
    }

    func disconnect() {
        session = nil
        KeychainStore.clear()
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
                .queryItems?.first(where: { $0.name == "code" })?.value
        else {
            lastError = "Strava did not return an authorization code."
            return
        }

        Task { await exchangeCode(code) }
    }

    private func exchangeCode(_ code: String) async {
        do {
            let tokens = try await BackendClient.exchange(code: code)
            let newSession = StravaSession(tokenResponse: tokens)
            KeychainStore.save(newSession)
            session = newSession
        } catch {
            lastError = "Could not complete Strava sign-in: \(error.localizedDescription)"
        }
    }

    /// Returns a valid access token, transparently refreshing it via the
    /// backend if it has expired.
    func validAccessToken() async throws -> String {
        guard var current = session else {
            throw StravaAPIClient.APIError.notAuthenticated
        }

        if current.isExpired {
            let tokens = try await BackendClient.refresh(refreshToken: current.refreshToken)
            current = StravaSession(tokenResponse: tokens)
            KeychainStore.save(current)
            session = current
        }

        return current.accessToken
    }
}

extension StravaAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
