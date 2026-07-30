import Foundation

/// Talks to Google's token endpoint directly. Unlike Strava, Google issues
/// no client secret for the "iOS" OAuth client type — PKCE proves the
/// request came from this app instead — so there's no secret to protect
/// and no backend involvement needed for Google auth.
enum GoogleTokenClient {
    enum TokenError: Error {
        case invalidResponse
        case server(String)
    }

    static func exchange(code: String, codeVerifier: String) async throws -> GoogleTokenResponse {
        try await post([
            "client_id": AppConfig.googleClientID,
            "code": code,
            "code_verifier": codeVerifier,
            "redirect_uri": AppConfig.googleRedirectURI,
            "grant_type": "authorization_code",
        ])
    }

    static func refresh(refreshToken: String) async throws -> GoogleTokenResponse {
        try await post([
            "client_id": AppConfig.googleClientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
        ])
    }

    private static func post(_ params: [String: String]) async throws -> GoogleTokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = params
            .map { "\($0.key)=\(Self.formEncode($0.value))" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TokenError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw TokenError.server(String(data: data, encoding: .utf8) ?? "Google token request failed")
        }

        return try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
    }

    private static func formEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
