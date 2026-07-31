import Combine
import Foundation
import HealthKit

struct StepPeriodTotals {
    let steps: Int
    let distanceMeters: Double
}

struct DailyStepPoint: Identifiable {
    let id: Date
    let date: Date
    let steps: Int
}

/// Daily step count + walking/running distance from Apple Health, rolled
/// up into this week/month/year totals plus a rolling-365-day daily
/// average. Separate from `HealthViewModel` (sleep/HR/HRV recovery data) —
/// same HealthKit authorization sheet under the hood (see
/// `HealthKitManager.readTypes`), but a distinct concern with its own tab.
@MainActor
final class StepsViewModel: ObservableObject {
    @Published private(set) var isAuthorized = false
    @Published private(set) var isLoading = false
    @Published private(set) var today: StepPeriodTotals?
    @Published private(set) var weekly: StepPeriodTotals?
    @Published private(set) var monthly: StepPeriodTotals?
    @Published private(set) var yearly: StepPeriodTotals?
    @Published private(set) var dailyAverageRollingYear: StepPeriodTotals?
    /// Last 30 days of step counts, oldest first, for the trend chart.
    @Published private(set) var recentDailySteps: [DailyStepPoint] = []
    @Published var errorMessage: String?

    /// The "avg per day" figure is over a full trailing year, not
    /// year-to-date — a stable "typical day" number that doesn't jump
    /// around early in January the way a YTD average would.
    private let rollingYearDays = 365
    private let recentChartDays = 30

    func requestAccess() async {
        do {
            try await HealthKitManager.requestAuthorization()
            isAuthorized = true
            await refresh()
        } catch {
            errorMessage = "Couldn't access Health data: \(error.localizedDescription)"
        }
    }

    func refresh() async {
        guard isAuthorized else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let calendar = Calendar.current
            let end = Date()
            let start = calendar.date(byAdding: .day, value: -(rollingYearDays - 1), to: calendar.startOfDay(for: end)) ?? end

            async let stepsByDay = HealthKitManager.fetchDailyQuantityTotals(for: .stepCount, unit: .count(), from: start, to: end)
            async let distanceByDay = HealthKitManager.fetchDailyQuantityTotals(for: .distanceWalkingRunning, unit: .meter(), from: start, to: end)
            let steps = try await stepsByDay
            let distance = try await distanceByDay

            computeTotals(steps: steps, distance: distance, rangeStart: start, rangeEnd: end)
        } catch {
            errorMessage = "Couldn't load step data: \(error.localizedDescription)"
        }
    }

    private func computeTotals(steps: [Date: Double], distance: [Date: Double], rangeStart: Date, rangeEnd: Date) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now

        today = Self.totals(steps: steps, distance: distance, since: todayStart)
        weekly = Self.totals(steps: steps, distance: distance, since: weekStart)
        monthly = Self.totals(steps: steps, distance: distance, since: monthStart)
        yearly = Self.totals(steps: steps, distance: distance, since: yearStart)

        let rolling = Self.totals(steps: steps, distance: distance, since: rangeStart)
        let daysInRange = max((calendar.dateComponents([.day], from: rangeStart, to: rangeEnd).day ?? 0) + 1, 1)
        dailyAverageRollingYear = StepPeriodTotals(
            steps: Int((Double(rolling.steps) / Double(daysInRange)).rounded()),
            distanceMeters: rolling.distanceMeters / Double(daysInRange)
        )

        guard let chartStart = calendar.date(byAdding: .day, value: -(recentChartDays - 1), to: calendar.startOfDay(for: now)) else { return }
        recentDailySteps = steps
            .filter { $0.key >= chartStart }
            .map { DailyStepPoint(id: $0.key, date: $0.key, steps: Int($0.value.rounded())) }
            .sorted { $0.date < $1.date }
    }

    private static func totals(steps: [Date: Double], distance: [Date: Double], since: Date) -> StepPeriodTotals {
        let matchedSteps = steps.filter { $0.key >= since }.values.reduce(0, +)
        let matchedDistance = distance.filter { $0.key >= since }.values.reduce(0, +)
        return StepPeriodTotals(steps: Int(matchedSteps.rounded()), distanceMeters: matchedDistance)
    }

    /// Plain-text summary, folded into the coach chat's context alongside
    /// the other Health data — see `CoachChatViewModel`.
    func summaryText() -> String {
        guard isAuthorized else { return "" }

        var lines: [String] = []
        if let today { lines.append("Today: \(today.steps) steps, \(Units.formattedMiles(today.distanceMeters))") }
        if let weekly { lines.append("This week: \(weekly.steps) steps, \(Units.formattedMiles(weekly.distanceMeters))") }
        if let monthly { lines.append("This month: \(monthly.steps) steps, \(Units.formattedMiles(monthly.distanceMeters))") }
        if let yearly { lines.append("This year: \(yearly.steps) steps, \(Units.formattedMiles(yearly.distanceMeters))") }
        if let dailyAverageRollingYear {
            lines.append("Daily average (trailing year): \(dailyAverageRollingYear.steps) steps, \(Units.formattedMiles(dailyAverageRollingYear.distanceMeters))")
        }

        guard !lines.isEmpty else { return "" }
        return "Steps & walking/running mileage (Apple Health):\n" + lines.joined(separator: "\n")
    }
}
