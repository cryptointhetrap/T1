import Foundation

/// A per-install random token, generated once and reused forever, that
/// forms the unguessable part of the athlete's `.ics` subscription URL —
/// same idea as a Google Calendar "private address". Not sensitive enough
/// for the Keychain (it's meant to be shared with a calendar app), so
/// plain `UserDefaults` is fine.
enum FeedTokenStore {
    private static let key = "com.trainingmonitor.app.calendar-feed-token"

    static func token() -> String {
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let generated = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }
}

/// Uploads the athlete's current schedule to the backend's feed store so
/// its `.ics` endpoint (any calendar app can subscribe to it) stays
/// current. The backend never sees anything else about the athlete — no
/// Strava data, no auth tokens — just this one feed's workouts, keyed by
/// the opaque token above.
struct CalendarFeedClient {
    enum APIError: Error {
        case requestFailed(Int)
    }

    let token: String

    var subscriptionURL: URL {
        AppConfig.backendBaseURL.appendingPathComponent("feed/\(token).ics")
    }

    func upload(_ workouts: [ScheduledWorkout]) async throws {
        let url = AppConfig.backendBaseURL.appendingPathComponent("feed/\(token)")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let body = ["workouts": workouts.map(FeedWorkout.init)]
        request.httpBody = try encoder.encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    private struct FeedWorkout: Encodable {
        let id: String
        let date: Date
        let sport: String
        let title: String
        let notes: String

        init(_ workout: ScheduledWorkout) {
            id = workout.id.uuidString
            date = workout.date
            sport = workout.sport
            title = workout.title
            notes = workout.notes
        }
    }
}
