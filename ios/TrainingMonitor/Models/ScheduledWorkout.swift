import Foundation

/// A future workout the athlete (or the coach chat, on their behalf) has
/// planned. Unlike `StravaActivity` this never comes from Strava — it's
/// stored locally on-device only.
struct ScheduledWorkout: Identifiable, Codable, Equatable {
    let id: UUID
    var date: Date
    var sport: String
    var title: String
    var notes: String
    /// Set once this workout has been mirrored to Google Calendar, so
    /// later edits/deletes update or remove that same event instead of
    /// creating a duplicate.
    var googleEventID: String?

    init(id: UUID = UUID(), date: Date, sport: String, title: String, notes: String = "", googleEventID: String? = nil) {
        self.id = id
        self.date = date
        self.sport = sport
        self.title = title
        self.notes = notes
        self.googleEventID = googleEventID
    }
}
