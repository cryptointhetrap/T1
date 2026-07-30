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

    init(id: UUID = UUID(), date: Date, sport: String, title: String, notes: String = "") {
        self.id = id
        self.date = date
        self.sport = sport
        self.title = title
        self.notes = notes
    }
}
