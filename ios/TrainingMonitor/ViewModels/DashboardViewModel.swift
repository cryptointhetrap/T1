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
    case swim = "Swim"
    case weightTraining = "Weight Training"
    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .run: return "figure.run"
        case .ride: return "figure.outdoor.cycle"
        case .swim: return "figure.pool.swim"
        case .weightTraining: return "dumbbell.fill"
        }
    }

    /// Run/ride/swim have a meaningful Strava distance; weight training
    /// doesn't (Strava always reports 0m), so its summary shows duration
    /// and session count instead — see `SportSummaryCard`.
    var tracksDistance: Bool {
        self != .weightTraining
    }

    static func matching(_ activity: StravaActivity) -> SportCategory? {
        if activity.type.contains("Run") { return .run }
        if activity.type.contains("Ride") { return .ride }
        if activity.type.contains("Swim") { return .swim }
        if activity.type.contains("WeightTraining") { return .weightTraining }
        return nil
    }
}

struct EfficiencyPoint: Identifiable {
    let id: Date // month start
    let monthStart: Date
    /// For rides with a real power meter (`deviceWatts == true`), this is
    /// Coggan's "Efficiency Factor" — weighted-average watts divided by
    /// average heart rate, the standard cycling-coach metric. Otherwise
    /// (runs, or rides without a power meter) it falls back to average
    /// speed (m/s) divided by average heart rate — a rougher proxy with
    /// the same "more output per heartbeat is better" shape. Either way
    /// it's from Strava's activity summaries, not full streams, so it
    /// isn't adjusted for terrain, wind, or heat.
    let efficiencyFactor: Double
    let usedPower: Bool
}

struct PeriodTotals {
    let distanceMeters: Double
    let elevationGainMeters: Double
    let movingTimeHours: Double
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
    @Published private(set) var efficiencyTrend: [SportCategory: [EfficiencyPoint]] = [:]
    /// Best efforts Strava currently ranks in the athlete's all-time top 3
    /// for their distance, found among recently-fetched run details. Not a
    /// full historical PR list — see the doc comment on
    /// `refreshPersonalRecords` for why.
    @Published private(set) var recentPersonalRecords: [BestEffort] = []
    /// This calendar month's relative effort, hours, and mileage across
    /// every activity (not just run/ride) — what gets pushed to a joined
    /// group for comparison. `nil` until the first successful refresh.
    @Published private(set) var currentMonthGroupStats: GroupMemberStats?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let activityProvider: ActivityProvider
    /// Only set when backed by Strava — PR lookups need Strava's
    /// per-activity detail endpoint, which Apple Health Workouts has no
    /// equivalent for (see `ActivitySourceStore`). `nil` just means
    /// `refreshPersonalRecords` is a no-op and Recent PRs never appears.
    private let prDetailClient: StravaAPIClient?
    /// Just over a year so calendar year-to-date totals are always complete,
    /// even in early January when "this year" only spans a few days.
    private let lookbackDays = 370
    /// The acute:chronic load trend only needs the trailing 90 days.
    private let loadTrendDays = 90
    /// How far back the aerobic efficiency trend looks.
    private let efficiencyTrendMonths = 6
    /// How many of the most recent runs to fetch full detail for, per
    /// refresh, in search of best efforts. Bounds the extra API calls.
    private let personalRecordLookbackCount = 20
    private var fetchedDetailActivityIDs: Set<Int> = []

    init(activityProvider: ActivityProvider, prDetailClient: StravaAPIClient? = nil) {
        self.activityProvider = activityProvider
        self.prDetailClient = prDetailClient
    }

    /// Checks the backend's cheap webhook-status endpoint and, only if
    /// there's a new event since the last time this device checked for
    /// this athlete, does a full `refresh()`. Meant to be called when the
    /// app comes to the foreground, as a much lighter alternative to
    /// always re-fetching the whole activity list on every foreground.
    /// Best-effort: any failure just means the caller's usual refresh
    /// cadence (pull-to-refresh, tab appearance) is the fallback.
    func refreshIfNewActivity(athleteID: Int) async {
        guard let latestEventAt = try? await WebhookStatusClient.latestEventAt(athleteID: athleteID) else { return }

        let key = Self.lastSeenEventKey(athleteID: athleteID)
        let lastSeen = UserDefaults.standard.object(forKey: key) as? Date
        guard lastSeen == nil || latestEventAt > lastSeen! else { return }

        UserDefaults.standard.set(latestEventAt, forKey: key)
        await refresh()
    }

    private static func lastSeenEventKey(athleteID: Int) -> String {
        "com.trainingmonitor.app.last-seen-webhook-event.\(athleteID)"
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let since = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: Date()) ?? Date()
            let activities = try await activityProvider.fetchActivities(after: since, before: nil)
            recentActivities = activities.sorted { $0.startDateLocal > $1.startDateLocal }
            weeklySummaries = Self.buildWeeklySummaries(from: activities)
            sportTotals = Self.buildSportTotals(from: activities)
            currentMonthGroupStats = Self.buildGroupStats(from: activities)
            efficiencyTrend = Self.buildEfficiencyTrend(from: activities, months: efficiencyTrendMonths)
            let series = Self.buildLoadSeries(from: activities, days: loadTrendDays)
            loadSeries = series
            if let latest = series.last, latest.chronicLoad > 0 {
                acuteChronicRatio = latest.acuteLoad / latest.chronicLoad
                trainingStatus = Self.status(forRatio: latest.acuteLoad / latest.chronicLoad)
            }
            await refreshPersonalRecords(from: activities)
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
                    movingTimeHours: yearly.movingTimeHours / weeksElapsedInYear,
                    activityCount: Int((Double(yearly.activityCount) / weeksElapsedInYear).rounded())
                )
            )
        }
        return result
    }

    /// Relative effort (Strava's suffer score, falling back to moving-time
    /// minutes when it's unavailable — same proxy `buildLoadSeries` uses),
    /// hours, and mileage summed across every activity this calendar
    /// month, regardless of sport.
    private static func buildGroupStats(from activities: [StravaActivity]) -> GroupMemberStats {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let monthActivities = activities.filter { $0.startDateLocal >= monthStart }

        let relativeEffort = monthActivities.reduce(0.0) { $0 + ($1.sufferScore ?? Double($1.movingTime) / 60) }
        let hours = Double(monthActivities.reduce(0) { $0 + $1.movingTime }) / 3600
        let miles = Units.miles(fromMeters: monthActivities.reduce(0) { $0 + $1.distance })
        return GroupMemberStats(relativeEffort: relativeEffort, hours: hours, miles: miles)
    }

    private static func totals(for activities: [StravaActivity], since: Date) -> PeriodTotals {
        let matched = activities.filter { $0.startDateLocal >= since }
        return PeriodTotals(
            distanceMeters: matched.reduce(0) { $0 + $1.distance },
            elevationGainMeters: matched.reduce(0) { $0 + $1.totalElevationGain },
            movingTimeHours: Double(matched.reduce(0) { $0 + $1.movingTime }) / 3600,
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

    /// Per-activity efficiency factor: real power-per-heartbeat when a
    /// power meter was used (rides only), otherwise speed-per-heartbeat.
    /// Returns `nil` for activities missing whatever it needs.
    private static func efficiencyFactor(for activity: StravaActivity) -> (value: Double, usedPower: Bool)? {
        guard let heartrate = activity.averageHeartrate, heartrate > 0 else { return nil }

        if activity.deviceWatts == true, let watts = activity.weightedAverageWatts ?? activity.averageWatts, watts > 0 {
            return (watts / heartrate, true)
        }
        if let speed = activity.averageSpeed, speed > 0 {
            return (speed / heartrate, false)
        }
        return nil
    }

    /// Monthly average efficiency factor per sport (see `EfficiencyPoint`).
    /// Skips a sport entirely if fewer than two months have data — one
    /// point isn't a trend.
    private static func buildEfficiencyTrend(from activities: [StravaActivity], months: Int) -> [SportCategory: [EfficiencyPoint]] {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .month, value: -months, to: Date()) else { return [:] }

        var result: [SportCategory: [EfficiencyPoint]] = [:]
        for category in SportCategory.allCases {
            let matched = activities.filter {
                SportCategory.matching($0) == category &&
                $0.startDateLocal >= cutoff &&
                efficiencyFactor(for: $0) != nil
            }
            guard !matched.isEmpty else { continue }

            let grouped = Dictionary(grouping: matched) { activity in
                calendar.dateInterval(of: .month, for: activity.startDateLocal)?.start ?? activity.startDateLocal
            }

            let points = grouped.compactMap { monthStart, monthActivities -> EfficiencyPoint? in
                let factors = monthActivities.compactMap { efficiencyFactor(for: $0) }
                guard !factors.isEmpty else { return nil }
                let average = factors.map(\.value).reduce(0, +) / Double(factors.count)
                let usedPower = factors.contains { $0.usedPower }
                return EfficiencyPoint(id: monthStart, monthStart: monthStart, efficiencyFactor: average, usedPower: usedPower)
            }
            .sorted { $0.monthStart < $1.monthStart }

            if points.count >= 2 {
                result[category] = points
            }
        }
        return result
    }

    /// Strava computes `pr_rank` (top-3-all-time) per effort at upload
    /// time, but only exposes it on the per-activity detail endpoint, not
    /// the activity-list summaries `refresh()` already has. Backfilling
    /// every run in "goes back forever" history would mean thousands of
    /// extra API calls, so instead this looks at only the most recent
    /// `personalRecordLookbackCount` runs (fetching each activity's detail
    /// exactly once, ever — `fetchedDetailActivityIDs` skips repeats on
    /// later refreshes) and keeps whatever current top-3 efforts turn up
    /// there. A PR set further back than that window won't appear here
    /// unless a recent run matched or beat it.
    private func refreshPersonalRecords(from activities: [StravaActivity]) async {
        guard let prDetailClient else { return }

        let candidates = activities
            .filter { SportCategory.matching($0) == .run }
            .sorted { $0.startDateLocal > $1.startDateLocal }
            .prefix(personalRecordLookbackCount)
            .filter { !fetchedDetailActivityIDs.contains($0.id) }

        guard !candidates.isEmpty else { return }

        var newEfforts: [BestEffort] = []
        for activity in candidates {
            fetchedDetailActivityIDs.insert(activity.id)
            guard let detail = try? await prDetailClient.fetchActivityDetail(id: activity.id) else { continue }
            if let efforts = detail.bestEfforts {
                newEfforts.append(contentsOf: efforts.filter { $0.prRank != nil })
            }
        }

        guard !newEfforts.isEmpty else { return }
        recentPersonalRecords = Self.mergeBestEfforts(existing: recentPersonalRecords, new: newEfforts)
    }

    /// Keeps one effort per distance name: whichever currently ranks
    /// higher (rank 1 beats rank 2 beats rank 3), breaking ties by recency.
    private static func mergeBestEfforts(existing: [BestEffort], new: [BestEffort]) -> [BestEffort] {
        var bestByName: [String: BestEffort] = [:]
        for effort in existing + new {
            guard let current = bestByName[effort.name] else {
                bestByName[effort.name] = effort
                continue
            }
            let currentRank = current.prRank ?? Int.max
            let newRank = effort.prRank ?? Int.max
            if newRank < currentRank || (newRank == currentRank && effort.startDateLocal > current.startDateLocal) {
                bestByName[effort.name] = effort
            }
        }
        return bestByName.values.sorted { $0.distance < $1.distance }
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
            if category.tracksDistance {
                lines.append(
                    "\(category.rawValue) — week: \(Units.formattedMiles(totals.weekly.distanceMeters)); " +
                    "month: \(Units.formattedMiles(totals.monthly.distanceMeters)); " +
                    "year: \(Units.formattedMiles(totals.yearly.distanceMeters)), \(Units.formattedFeet(totals.yearly.elevationGainMeters)) gain"
                )
            } else {
                lines.append(
                    "\(category.rawValue) — week: \(String(format: "%.1f", totals.weekly.movingTimeHours)) h, " +
                    "\(totals.weekly.activityCount) sessions; month: \(String(format: "%.1f", totals.monthly.movingTimeHours)) h, " +
                    "\(totals.monthly.activityCount) sessions; year: \(String(format: "%.1f", totals.yearly.movingTimeHours)) h, " +
                    "\(totals.yearly.activityCount) sessions"
                )
            }
        }

        if !recentActivities.isEmpty {
            lines.append("Recent activities:")
            for activity in recentActivities.prefix(10) {
                var line = "- \(activity.startDateLocal.formatted(date: .abbreviated, time: .omitted)): " +
                    "\(activity.name) (\(activity.type), \(Units.formattedMiles(activity.distance)), \(activity.movingTime / 60) min"
                if activity.deviceWatts == true, let watts = activity.weightedAverageWatts ?? activity.averageWatts {
                    line += ", \(String(format: "%.0f", watts))w avg"
                }
                if let kilojoules = activity.kilojoules, kilojoules > 0 {
                    line += ", \(String(format: "%.0f", kilojoules)) kJ"
                }
                line += ")"
                lines.append(line)
            }
        }

        if !recentPersonalRecords.isEmpty {
            lines.append("Current top-3-all-time run efforts (from recent activities):")
            for effort in recentPersonalRecords {
                let rankLabel = ["1": "PR", "2": "#2 all-time", "3": "#3 all-time"][String(effort.prRank ?? 0)] ?? "top 3"
                lines.append("- \(effort.name): \(Self.formattedDuration(effort.movingTime)) (\(rankLabel), set \(effort.startDateLocal.formatted(date: .abbreviated, time: .omitted)))")
            }
        }

        for category in SportCategory.allCases {
            guard let points = efficiencyTrend[category], let first = points.first, let last = points.last, first.efficiencyFactor > 0 else { continue }
            let percentChange = ((last.efficiencyFactor - first.efficiencyFactor) / first.efficiencyFactor) * 100
            let direction = percentChange >= 0 ? "up" : "down"
            let basis = last.usedPower ? "power per heartbeat" : "speed per heartbeat"
            lines.append(
                "\(category.rawValue) aerobic efficiency (\(basis)) trending \(direction) " +
                "\(String(format: "%.0f", abs(percentChange)))% over the last \(points.count) months — a rough " +
                "fitness/fatigue-resistance proxy from Strava's activity summaries, not adjusted for terrain or weather."
            )
        }

        return lines.joined(separator: "\n")
    }

    /// Progress against the athlete's own weekly targets (`GoalsStore`), for
    /// the coach chat context — same "current calendar week" totals the
    /// Stats tab's rings (`WeeklyGoalRings`) show. Empty string if no goal
    /// is set at all.
    func goalsSummaryText(_ goals: WeeklyGoals) -> String {
        guard !goals.isEmpty else { return "" }
        let week = weeklySummaries.last

        var lines = ["Weekly goals (progress so far this calendar week):"]
        if let target = goals.distanceMiles {
            let actual = Units.miles(fromMeters: week?.distanceMeters ?? 0)
            lines.append("- Distance: \(String(format: "%.1f", actual)) / \(String(format: "%.0f", target)) mi")
        }
        if let target = goals.timeHours {
            let actual = week?.movingTimeHours ?? 0
            lines.append("- Time: \(String(format: "%.1f", actual)) / \(String(format: "%.0f", target)) h")
        }
        if let target = goals.elevationFeet {
            let actual = Units.feet(fromMeters: week?.elevationGainMeters ?? 0)
            lines.append("- Elevation: \(String(format: "%.0f", actual)) / \(String(format: "%.0f", target)) ft")
        }
        return lines.joined(separator: "\n")
    }

    private static func formattedDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
