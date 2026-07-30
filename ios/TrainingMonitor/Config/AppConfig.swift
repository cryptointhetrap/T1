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

    /// From an "iOS" OAuth client created in Google Cloud Console (APIs &
    /// Services → Credentials) with the Calendar API enabled. Google issues
    /// no client secret for this client type — auth is proved via PKCE
    /// instead, so this never touches the backend. Must match the
    /// reversed-client-ID URL scheme registered in Info.plist.
    static let googleClientID = "REPLACE_WITH_GOOGLE_IOS_CLIENT_ID.apps.googleusercontent.com"
    static let googleRedirectScheme = "com.googleusercontent.apps.REPLACE_WITH_GOOGLE_IOS_CLIENT_ID"
    static let googleRedirectURI = "\(googleRedirectScheme):/oauth2redirect"
    static let googleCalendarScopes = "https://www.googleapis.com/auth/calendar.events"
}
