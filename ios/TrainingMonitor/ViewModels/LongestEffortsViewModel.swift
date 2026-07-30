import Combine
import Foundation

@MainActor
final class LongestEffortsViewModel: ObservableObject {
    @Published private(set) var topRuns: [StravaActivity] = []
    @Published private(set) var topRides: [StravaActivity] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let apiClient: StravaAPIClient
    private let topCount = 10

    init(apiClient: StravaAPIClient) {
        self.apiClient = apiClient
    }

    /// Only loads once per screen visit — this is a genuinely all-time
    /// query (no lower date bound, unlike the Dashboard's ~370-day
    /// window), so for an athlete with years of Strava history it can mean
    /// paginating through a lot of activities. Pull-to-refresh forces a
    /// re-fetch if new activities should be considered.
    func loadIfNeeded() async {
        guard topRuns.isEmpty && topRides.isEmpty else { return }
        await load()
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let allTime = Date(timeIntervalSince1970: 0)
            let activities = try await apiClient.fetchActivities(after: allTime)
            topRuns = Self.longest(activities, matching: .run, count: topCount)
            topRides = Self.longest(activities, matching: .ride, count: topCount)
        } catch {
            errorMessage = "Couldn't load your full activity history: \(error.localizedDescription)"
        }
    }

    private static func longest(_ activities: [StravaActivity], matching category: SportCategory, count: Int) -> [StravaActivity] {
        activities
            .filter { SportCategory.matching($0) == category }
            .sorted { $0.distance > $1.distance }
            .prefix(count)
            .map { $0 }
    }
}
