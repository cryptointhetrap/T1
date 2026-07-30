import Foundation

struct StravaTokenResponse: Codable {
    let tokenType: String
    let expiresAt: Int
    let expiresIn: Int
    let refreshToken: String
    let accessToken: String
    let athlete: StravaAthlete?

    enum CodingKeys: String, CodingKey {
        case tokenType = "token_type"
        case expiresAt = "expires_at"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case accessToken = "access_token"
        case athlete
    }
}

struct StravaAthlete: Codable {
    let id: Int
    let firstname: String?
    let lastname: String?
}

/// Persisted locally in the Keychain. `expiresAt` is a Unix timestamp
/// matching Strava's `expires_at` semantics.
struct StravaSession: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let athleteID: Int?

    var isExpired: Bool {
        Date() >= expiresAt.addingTimeInterval(-60)
    }

    init(tokenResponse: StravaTokenResponse) {
        self.accessToken = tokenResponse.accessToken
        self.refreshToken = tokenResponse.refreshToken
        self.expiresAt = Date(timeIntervalSince1970: TimeInterval(tokenResponse.expiresAt))
        self.athleteID = tokenResponse.athlete?.id
    }

    init(accessToken: String, refreshToken: String, expiresAt: Date, athleteID: Int?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.athleteID = athleteID
    }
}

struct StravaActivity: Codable, Identifiable {
    let id: Int
    let name: String
    let type: String
    let distance: Double // meters
    let movingTime: Int // seconds
    let elapsedTime: Int // seconds
    let totalElevationGain: Double // meters
    let startDateLocal: Date
    let averageHeartrate: Double?
    let averageSpeed: Double? // meters/second
    /// Strava's "Relative Effort" score. Only present for some
    /// activities/athletes (requires heart rate data or a premium account).
    let sufferScore: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, type, distance
        case movingTime = "moving_time"
        case elapsedTime = "elapsed_time"
        case totalElevationGain = "total_elevation_gain"
        case startDateLocal = "start_date_local"
        case averageHeartrate = "average_heartrate"
        case averageSpeed = "average_speed"
        case sufferScore = "suffer_score"
    }
}
