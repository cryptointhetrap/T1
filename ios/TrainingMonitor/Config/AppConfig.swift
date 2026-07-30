import Foundation

/// Fill these in before running the app. `stravaClientID` comes from your
/// registered app at https://www.strava.com/settings/api; `backendBaseURL`
/// is wherever you deployed the `backend/` service from this repo.
enum AppConfig {
    static let stravaClientID = "REPLACE_WITH_STRAVA_CLIENT_ID"
    static let backendBaseURL = URL(string: "http://localhost:8787")!

    static let oauthRedirectScheme = "trainingmonitor"
    static let oauthRedirectURI = "trainingmonitor://oauth-callback"
    static let oauthScopes = "read,activity:read_all"
}
