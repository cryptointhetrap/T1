import Foundation

/// Talks to intervals.icu directly from the device using a self-serve API
/// key the athlete generates themselves — no OAuth flow, no backend
/// involvement, same shape as how `StravaAPIClient` and
/// `GoogleCalendarAPIClient` talk to their APIs. Auth is HTTP Basic with
/// the literal username `API_KEY` and the athlete's key as the password,
/// per intervals.icu's documented convention.
final class IntervalsICUAPIClient {
    enum APIError: Error {
        case requestFailed(Int)
    }

    private let credentials: IntervalsICUCredentials
    private let baseURL = URL(string: "https://intervals.icu/api/v1")!

    init(credentials: IntervalsICUCredentials) {
        self.credentials = credentials
    }

    /// Confirms the athlete ID / API key pair actually works before saving it.
    func verifyCredentials() async throws {
        let url = baseURL.appendingPathComponent("athlete/\(credentials.athleteID)")
        let (_, http) = try await request(url: url, method: "GET", body: nil)
        guard (200..<300).contains(http.statusCode) else { throw APIError.requestFailed(http.statusCode) }
    }

    func fetchWellness(sinceDays: Int) async throws -> [IntervalsWellness] {
        let oldest = Calendar.current.date(byAdding: .day, value: -sinceDays, to: Date()) ?? Date()
        var components = URLComponents(
            url: baseURL.appendingPathComponent("athlete/\(credentials.athleteID)/wellness.json"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "oldest", value: Self.dayFormatter.string(from: oldest)),
            URLQueryItem(name: "newest", value: Self.dayFormatter.string(from: Date())),
        ]

        let (data, http) = try await request(url: components.url!, method: "GET", body: nil)
        guard (200..<300).contains(http.statusCode) else { throw APIError.requestFailed(http.statusCode) }
        return try JSONDecoder().decode([IntervalsWellness].self, from: data)
    }

    @discardableResult
    func createEvent(for workout: ScheduledWorkout) async throws -> Int {
        let url = baseURL.appendingPathComponent("athlete/\(credentials.athleteID)/events")
        let (data, http) = try await request(url: url, method: "POST", body: Self.eventBody(for: workout))
        guard (200..<300).contains(http.statusCode) else { throw APIError.requestFailed(http.statusCode) }
        return try JSONDecoder().decode(CreatedEvent.self, from: data).id
    }

    func updateEvent(eventID: Int, workout: ScheduledWorkout) async throws {
        let url = baseURL.appendingPathComponent("athlete/\(credentials.athleteID)/events/\(eventID)")
        let (_, http) = try await request(url: url, method: "PUT", body: Self.eventBody(for: workout))
        guard (200..<300).contains(http.statusCode) else { throw APIError.requestFailed(http.statusCode) }
    }

    func deleteEvent(eventID: Int) async throws {
        let url = baseURL.appendingPathComponent("athlete/\(credentials.athleteID)/events/\(eventID)")
        let (_, http) = try await request(url: url, method: "DELETE", body: nil)
        // 404 means it was already deleted on the intervals.icu side — treat as success.
        guard (200..<300).contains(http.statusCode) || http.statusCode == 404 else {
            throw APIError.requestFailed(http.statusCode)
        }
    }

    private func request(url: URL, method: String, body: [String: Any]?) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        let token = Data("API_KEY:\(credentials.apiKey)".utf8).base64EncodedString()
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.requestFailed(-1) }
        return (data, http)
    }

    private static func eventBody(for workout: ScheduledWorkout) -> [String: Any] {
        [
            "category": "WORKOUT",
            "start_date_local": localDateTimeFormatter.string(from: workout.date),
            "type": intervalsType(for: workout.sport),
            "name": workout.title,
            "description": workout.notes,
        ]
    }

    private static func intervalsType(for sport: String) -> String {
        let lowercased = sport.lowercased()
        if lowercased.contains("run") { return "Run" }
        if lowercased.contains("ride") || lowercased.contains("bike") || lowercased.contains("cycl") { return "Ride" }
        return "Other"
    }

    private struct CreatedEvent: Decodable {
        let id: Int
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// intervals.icu takes `start_date_local` as a naive local datetime
    /// with no UTC offset, matching how the athlete's account timezone is
    /// configured on their end.
    private static let localDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
}
