import Foundation

/// Which provider is backing the Stats/Calendar tabs when there's no
/// connected Strava session — see `ActivitySourceStore` and
/// `ConnectStravaView`'s second button. A connected Strava session always
/// takes priority in `RootView`, so this only matters pre-Strava.
enum ActivitySource: String, Codable {
    case strava
    case appleHealth
}
