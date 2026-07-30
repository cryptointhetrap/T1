import Combine
import Foundation

@MainActor
final class GoogleCalendarViewModel: ObservableObject {
    @Published private(set) var upcomingEvents: [GoogleCalendarEvent] = []
    @Published var errorMessage: String?

    private let authManager: GoogleAuthManager
    private let apiClient: GoogleCalendarAPIClient

    init(authManager: GoogleAuthManager, apiClient: GoogleCalendarAPIClient) {
        self.authManager = authManager
        self.apiClient = apiClient
    }

    var isConnected: Bool { authManager.isConnected }

    func connect() { authManager.connect() }
    func disconnect() { authManager.disconnect() }

    func refresh() async {
        guard isConnected else {
            upcomingEvents = []
            return
        }
        let now = Date()
        guard let horizon = Calendar.current.date(byAdding: .day, value: 14, to: now) else { return }
        do {
            upcomingEvents = try await apiClient.listEvents(from: now, to: horizon).sorted { $0.start < $1.start }
        } catch {
            errorMessage = "Couldn't load your Google Calendar: \(error.localizedDescription)"
        }
    }

    /// Plain-text upcoming-events summary, appended to the coach chat's
    /// context so Claude can avoid proposing a workout time that overlaps
    /// something already on the calendar.
    func conflictContextText() -> String {
        guard isConnected else { return "" }
        guard !upcomingEvents.isEmpty else {
            return "Upcoming Google Calendar events (next 14 days): none."
        }

        var lines = ["Upcoming Google Calendar events (next 14 days, for conflict awareness):"]
        for event in upcomingEvents.prefix(30) {
            if event.isAllDay {
                lines.append("- \(event.start.formatted(date: .abbreviated, time: .omitted)) (all day): \(event.title)")
            } else {
                lines.append(
                    "- \(event.start.formatted(date: .abbreviated, time: .shortened))" +
                    "–\(event.end.formatted(date: .omitted, time: .shortened)): \(event.title)"
                )
            }
        }
        return lines.joined(separator: "\n")
    }
}
