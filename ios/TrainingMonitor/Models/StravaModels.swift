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
    let averageWatts: Double?
    /// Only present on rides, and only meaningful (per Strava's docs) when
    /// `deviceWatts` is true — an estimated-power ride has no
    /// weighted-average figure.
    let weightedAverageWatts: Double?
    /// True when `averageWatts`/`weightedAverageWatts` came from a real
    /// power meter rather than Strava's speed-based estimate. Estimated
    /// power isn't reliable enough to compute an efficiency factor from.
    let deviceWatts: Bool?
    let kilojoules: Double?
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
        case averageWatts = "average_watts"
        case weightedAverageWatts = "weighted_average_watts"
        case deviceWatts = "device_watts"
        case kilojoules
        case sufferScore = "suffer_score"
    }
}

/// The subset of Strava's `DetailedActivity` (fetched per-activity via
/// `GET /activities/{id}`, unlike everything else in this file which comes
/// from the cheaper activity-list summaries) that this app uses: the
/// athlete's best-effort times for standard distances within that activity,
/// each flagged with its current all-time rank when it's a top-3 effort.
struct StravaActivityDetail: Codable {
    let id: Int
    let bestEfforts: [BestEffort]?

    enum CodingKeys: String, CodingKey {
        case id
        case bestEfforts = "best_efforts"
    }
}

struct BestEffort: Codable, Identifiable {
    let name: String // e.g. "5k", "10k", "Half-Marathon"
    let distance: Double // meters
    let movingTime: Int // seconds
    let startDateLocal: Date
    /// 1, 2, or 3 when this effort currently ranks in the athlete's
    /// all-time top 3 for this distance; absent otherwise.
    let prRank: Int?

    var id: String { "\(name)-\(startDateLocal.timeIntervalSince1970)" }

    enum CodingKeys: String, CodingKey {
        case name, distance
        case movingTime = "moving_time"
        case startDateLocal = "start_date_local"
        case prRank = "pr_rank"
    }
}
