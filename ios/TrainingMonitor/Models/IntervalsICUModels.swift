import Foundation

/// A self-serve API key from https://intervals.icu/settings → Developer,
/// paired with the athlete's numeric ID (also shown there). Unlike Strava
/// or Google this needs no OAuth flow at all.
struct IntervalsICUCredentials: Codable {
    let athleteID: String
    let apiKey: String
}

/// One day of intervals.icu's own training-load model — the same
/// exponentially-weighted CTL (fitness) / ATL (fatigue) approach
/// TrainingPeaks etc. use, computed by intervals.icu from the athlete's
/// full synced history (which can include power/HR streams from Garmin,
/// Wahoo, etc.), rather than the coarser suffer-score proxy this app's own
/// dashboard uses. Field names/availability come from intervals.icu's
/// community-documented API rather than a published formal schema, so
/// unrecognized or missing fields are tolerated (all optional).
struct IntervalsWellness: Codable {
    let id: String // yyyy-MM-dd
    let ctl: Double?
    let atl: Double?
    let rampRate: Double?
    let restingHR: Int?
    let hrv: Double?
    let sleepSecs: Int?
    let readiness: Double?
}
