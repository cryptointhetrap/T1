import Combine
import Foundation

struct WeekSummary: Identifiable {
    let id: Date // week start
    let weekStart: Date
    let distanceKm: Double
    let movingTimeHours: Double
    let elevationGainM: Double
    let activityCount: Int
}

struct DailyLoadPoint: Identifiable {
    let id: Date
    let date: Date
    let acuteLoad: Double // 7-day rolling average of daily load
    let chronicLoad: Double // 28-day rolling average of daily load
}

enum TrainingStatus: String {
    case rampingUp = "Ramping up"
    case optimal = "Optimal"
    case highRisk = "High load"
    case detraining = "Detraining"
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var weeklySummaries: [WeekSummary] = []
    @Published private(set) var loadSeries: [DailyLoadPoint] = []
    @Published private(set) var recentActivities: [StravaActivity] = []
    @Published private(set) var acuteChronicRatio: Double?
    @Published private(set) var trainingStatus: TrainingStatus?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let apiClient: StravaAPIClient
    private let lookbackDays = 90

    init(apiClient: StravaAPIClient) {
        self.apiClient = apiClient
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let since = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: Date()) ?? Date()
            let activities = try await apiClient.fetchActivities(after: since)
            recentActivities = activities.sorted { $0.startDateLocal > $1.startDateLocal }
            weeklySummaries = Self.buildWeeklySummaries(from: activities)
            let series = Self.buildLoadSeries(from: activities, days: lookbackDays)
            loadSeries = series
            if let latest = series.last, latest.chronicLoad > 0 {
                acuteChronicRatio = latest.acuteLoad / latest.chronicLoad
                trainingStatus = Self.status(forRatio: latest.acuteLoad / latest.chronicLoad)
            }
        } catch {
            errorMessage = "Couldn't load your activities: \(error.localizedDescription)"
        }
    }

    private static func buildWeeklySummaries(from activities: [StravaActivity]) -> [WeekSummary] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: activities) { activity in
            calendar.dateInterval(of: .weekOfYear, for: activity.startDateLocal)?.start ?? activity.startDateLocal
        }

        return grouped.map { weekStart, activities in
            WeekSummary(
                id: weekStart,
                weekStart: weekStart,
                distanceKm: activities.reduce(0) { $0 + $1.distance } / 1000,
                movingTimeHours: Double(activities.reduce(0) { $0 + $1.movingTime }) / 3600,
                elevationGainM: activities.reduce(0) { $0 + $1.totalElevationGain },
                activityCount: activities.count
            )
        }
        .sorted { $0.weekStart < $1.weekStart }
    }

    /// Uses each activity's Strava "suffer score" (Relative Effort) when
    /// available, otherwise falls back to moving-time minutes as a proxy for
    /// daily training load, then computes 7-day (acute) vs 28-day (chronic)
    /// rolling averages — the standard acute:chronic workload approach used
    /// to flag ramping-too-fast risk.
    private static func buildLoadSeries(from activities: [StravaActivity], days: Int) -> [DailyLoadPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let rangeStart = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }

        var dailyLoad: [Date: Double] = [:]
        for activity in activities {
            let day = calendar.startOfDay(for: activity.startDateLocal)
            let load = activity.sufferScore ?? Double(activity.movingTime) / 60
            dailyLoad[day, default: 0] += load
        }

        var orderedDays: [Date] = []
        var cursor = rangeStart
        while cursor <= today {
            orderedDays.append(cursor)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        let loads = orderedDays.map { dailyLoad[$0] ?? 0 }

        var points: [DailyLoadPoint] = []
        for index in orderedDays.indices {
            let acuteWindow = loads[max(0, index - 6)...index]
            let chronicStart = max(0, index - 27)
            let chronicWindow = loads[chronicStart...index]
            let acuteAvg = acuteWindow.reduce(0, +) / Double(acuteWindow.count)
            let chronicAvg = chronicWindow.reduce(0, +) / Double(chronicWindow.count)
            points.append(DailyLoadPoint(id: orderedDays[index], date: orderedDays[index], acuteLoad: acuteAvg, chronicLoad: chronicAvg))
        }
        return points
    }

    private static func status(forRatio ratio: Double) -> TrainingStatus {
        switch ratio {
        case ..<0.8: return .detraining
        case 0.8..<1.3: return .optimal
        case 1.3..<1.5: return .rampingUp
        default: return .highRisk
        }
    }
}
