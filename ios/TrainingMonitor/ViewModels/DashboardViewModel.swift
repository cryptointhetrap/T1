import Combine
import Foundation

struct WeekSummary: Identifiable {
    let id: Date // week start
    let weekStart: Date
    let distanceMeters: Double
    let movingTimeHours: Double
    let elevationGainMeters: Double
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

enum SportCategory: String, CaseIterable, Identifiable {
    case run = "Run"
    case ride = "Bike"
    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .run: return "figure.run"
        case .ride: return "figure.outdoor.cycle"
        }
    }

    static func matching(_ activity: StravaActivity) -> SportCategory? {
        if activity.type.contains("Run") { return .run }
        if activity.type.contains("Ride") { return .ride }
        return nil
    }
}

struct PeriodTotals {
    let distanceMeters: Double
    let elevationGainMeters: Double
    let activityCount: Int
}

struct SportTotals {
    let weekly: PeriodTotals
    let monthly: PeriodTotals
    let yearly: PeriodTotals
    /// Year-to-date totals divided by weeks elapsed so far this year — a
    /// rolling per-week average that rises/falls as the year progresses,
    /// rather than a fixed weekly snapshot.
    let weeklyAverageForYear: PeriodTotals
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var weeklySummaries: [WeekSummary] = []
    @Published private(set) var loadSeries: [DailyLoadPoint] = []
    @Published private(set) var recentActivities: [StravaActivity] = []
    @Published private(set) var acuteChronicRatio: Double?
    @Published private(set) var trainingStatus: TrainingStatus?
    @Published private(set) var sportTotals: [SportCategory: SportTotals] = [:]
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let apiClient: StravaAPIClient
    /// Just over a year so calendar year-to-date totals are always complete,
    /// even in early January when "this year" only spans a few days.
    private let lookbackDays = 370
    /// The acute:chronic load trend only needs the trailing 90 days.
    private let loadTrendDays = 90

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
            sportTotals = Self.buildSportTotals(from: activities)
            let series = Self.buildLoadSeries(from: activities, days: loadTrendDays)
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
                distanceMeters: activities.reduce(0) { $0 + $1.distance },
                movingTimeHours: Double(activities.reduce(0) { $0 + $1.movingTime }) / 3600,
                elevationGainMeters: activities.reduce(0) { $0 + $1.totalElevationGain },
                activityCount: activities.count
            )
        }
        .sorted { $0.weekStart < $1.weekStart }
    }

    /// Totals per sport (run/bike) for the current calendar week, month, and
    /// year, so the Bike & Run section always reads "this week / this month
    /// / this year" rather than a rolling window.
    private static func buildSportTotals(from activities: [StravaActivity]) -> [SportCategory: SportTotals] {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now

        let daysElapsedInYear = calendar.dateComponents([.day], from: yearStart, to: now).day ?? 0
        let weeksElapsedInYear = max(Double(daysElapsedInYear + 1) / 7, 1)

        var result: [SportCategory: SportTotals] = [:]
        for category in SportCategory.allCases {
            let matched = activities.filter { SportCategory.matching($0) == category }
            let yearly = totals(for: matched, since: yearStart)
            result[category] = SportTotals(
                weekly: totals(for: matched, since: weekStart),
                monthly: totals(for: matched, since: monthStart),
                yearly: yearly,
                weeklyAverageForYear: PeriodTotals(
                    distanceMeters: yearly.distanceMeters / weeksElapsedInYear,
                    elevationGainMeters: yearly.elevationGainMeters / weeksElapsedInYear,
                    activityCount: Int((Double(yearly.activityCount) / weeksElapsedInYear).rounded())
                )
            )
        }
        return result
    }

    private static func totals(for activities: [StravaActivity], since: Date) -> PeriodTotals {
        let matched = activities.filter { $0.startDateLocal >= since }
        return PeriodTotals(
            distanceMeters: matched.reduce(0) { $0 + $1.distance },
            elevationGainMeters: matched.reduce(0) { $0 + $1.totalElevationGain },
            activityCount: matched.count
        )
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

    /// A compact plain-text summary of the athlete's currently-loaded stats,
    /// sent to the coach chat backend as grounding context so Claude answers
    /// from the athlete's actual data rather than guessing.
    func trainingSummaryText() -> String {
        var lines: [String] = []

        if let status = trainingStatus, let ratio = acuteChronicRatio {
            lines.append("Training status: \(status.rawValue) (acute:chronic ratio \(String(format: "%.2f", ratio)))")
        }

        if let week = weeklySummaries.last {
            lines.append(
                "This week overall: \(Units.formattedMiles(week.distanceMeters)), " +
                "\(String(format: "%.1f", week.movingTimeHours)) h, " +
                "\(Units.formattedFeet(week.elevationGainMeters)) gain, \(week.activityCount) activities"
            )
        }

        for category in SportCategory.allCases {
            guard let totals = sportTotals[category] else { continue }
            lines.append(
                "\(category.rawValue) — week: \(Units.formattedMiles(totals.weekly.distanceMeters)); " +
                "month: \(Units.formattedMiles(totals.monthly.distanceMeters)); " +
                "year: \(Units.formattedMiles(totals.yearly.distanceMeters)), \(Units.formattedFeet(totals.yearly.elevationGainMeters)) gain"
            )
        }

        if !recentActivities.isEmpty {
            lines.append("Recent activities:")
            for activity in recentActivities.prefix(10) {
                lines.append(
                    "- \(activity.startDateLocal.formatted(date: .abbreviated, time: .omitted)): " +
                    "\(activity.name) (\(activity.type), \(Units.formattedMiles(activity.distance)), \(activity.movingTime / 60) min)"
                )
            }
        }

        return lines.joined(separator: "\n")
    }
}
