import Foundation

/// Anything that can list activities for a date range — implemented by
/// `StravaAPIClient` (Strava) and `HealthKitActivityProvider` (Apple
/// Health Workouts), so `DashboardViewModel`/`CalendarViewModel` don't
/// need to know which one is backing them. See `ActivitySourceStore` for
/// how the athlete picks between the two.
protocol ActivityProvider {
    func fetchActivities(after: Date, before: Date?) async throws -> [StravaActivity]
}

extension StravaAPIClient: ActivityProvider {
    func fetchActivities(after: Date, before: Date?) async throws -> [StravaActivity] {
        try await fetchActivities(after: after, before: before, perPage: 100)
    }
}
