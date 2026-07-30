import Foundation

/// Google's token endpoint response. For the "iOS" OAuth client type,
/// Google issues no client secret — auth is proved via PKCE instead, so
/// this never needs to touch our backend the way Strava's tokens do.
struct GoogleTokenResponse: Codable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String?
    let tokenType: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case tokenType = "token_type"
    }
}

/// Persisted in the Keychain. Google's refresh grant does not return a new
/// refresh token, so callers must carry the original one forward.
struct GoogleSession: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date

    var isExpired: Bool {
        Date() >= expiresAt.addingTimeInterval(-60)
    }

    init(tokenResponse: GoogleTokenResponse, fallbackRefreshToken: String? = nil) {
        self.accessToken = tokenResponse.accessToken
        self.refreshToken = tokenResponse.refreshToken ?? fallbackRefreshToken
        self.expiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
    }
}
