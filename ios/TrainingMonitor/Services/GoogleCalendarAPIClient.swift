import Foundation

struct GoogleCalendarEvent: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
}

/// Calls the Google Calendar API directly using the athlete's access token,
/// mirroring how `StravaAPIClient` talks to Strava. No backend involved.
final class GoogleCalendarAPIClient {
    enum APIError: Error {
        case notAuthenticated
        case requestFailed(Int)
    }

    private let authManager: GoogleAuthManager
    private let baseURL = URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!

    init(authManager: GoogleAuthManager) {
        self.authManager = authManager
    }

    func listEvents(from start: Date, to end: Date) async throws -> [GoogleCalendarEvent] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: Self.dateTimeFormatter.string(from: start)),
            URLQueryItem(name: "timeMax", value: Self.dateTimeFormatter.string(from: end)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
        ]

        let (data, http) = try await authorizedRequest(url: components.url!, method: "GET", body: nil)
        guard (200..<300).contains(http.statusCode) else { throw APIError.requestFailed(http.statusCode) }

        let decoded = try JSONDecoder().decode(EventsListResponse.self, from: data)
        return decoded.items.compactMap { item -> GoogleCalendarEvent? in
            guard
                let start = Self.parseEventTime(item.start),
                let end = Self.parseEventTime(item.end)
            else { return nil }
            return GoogleCalendarEvent(
                id: item.id,
                title: item.summary ?? "(untitled)",
                start: start,
                end: end,
                isAllDay: item.start.dateTime == nil
            )
        }
    }

    @discardableResult
    func createEvent(for workout: ScheduledWorkout) async throws -> String {
        let (data, http) = try await authorizedRequest(url: baseURL, method: "POST", body: Self.eventBody(for: workout))
        guard (200..<300).contains(http.statusCode) else { throw APIError.requestFailed(http.statusCode) }
        return try JSONDecoder().decode(CreatedEvent.self, from: data).id
    }

    func updateEvent(eventID: String, workout: ScheduledWorkout) async throws {
        let url = baseURL.appendingPathComponent(eventID)
        let (_, http) = try await authorizedRequest(url: url, method: "PATCH", body: Self.eventBody(for: workout))
        guard (200..<300).contains(http.statusCode) else { throw APIError.requestFailed(http.statusCode) }
    }

    func deleteEvent(eventID: String) async throws {
        let url = baseURL.appendingPathComponent(eventID)
        let (_, http) = try await authorizedRequest(url: url, method: "DELETE", body: nil)
        // 410 Gone means it was already deleted on the Google side — treat as success.
        guard (200..<300).contains(http.statusCode) || http.statusCode == 410 else {
            throw APIError.requestFailed(http.statusCode)
        }
    }

    private func authorizedRequest(url: URL, method: String, body: [String: Any]?) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(try await authManager.validAccessToken())", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.requestFailed(-1) }
        return (data, http)
    }

    private static func eventBody(for workout: ScheduledWorkout) -> [String: Any] {
        let end = Calendar.current.date(byAdding: .hour, value: 1, to: workout.date) ?? workout.date
        return [
            "summary": "\(workout.sport): \(workout.title)",
            "description": workout.notes,
            "start": ["dateTime": dateTimeFormatter.string(from: workout.date), "timeZone": TimeZone.current.identifier],
            "end": ["dateTime": dateTimeFormatter.string(from: end), "timeZone": TimeZone.current.identifier],
        ]
    }

    private static func parseEventTime(_ time: EventTime) -> Date? {
        if let dateTimeString = time.dateTime {
            return dateTimeFormatter.date(from: dateTimeString)
        }
        if let dateString = time.date {
            return dayFormatter.date(from: dateString)
        }
        return nil
    }

    private struct EventTime: Decodable {
        let dateTime: String?
        let date: String?
    }

    private struct EventsListResponse: Decodable {
        struct Item: Decodable {
            let id: String
            let summary: String?
            let start: EventTime
            let end: EventTime
        }
        let items: [Item]
    }

    private struct CreatedEvent: Decodable {
        let id: String
    }

    private static let dateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
