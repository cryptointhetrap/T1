import Foundation
import HealthKit
import UserNotifications

/// Runs when a silent push tells the app a new Strava activity just
/// synced (`AppDelegate.application(_:didReceiveRemoteNotification:...)`).
/// Gathers that activity's own performance plus recent Health/
/// intervals.icu recovery context — all on-device, since HealthKit data
/// never leaves the phone — asks the backend for a short AI review,
/// stores it (`WorkoutReviewStore`) so the Stats tab can show it later,
/// and posts a local notification with the result. The silent push itself
/// carries no user-visible alert, since the review text isn't known until
/// this finishes.
@MainActor
enum WorkoutReviewGenerator {
    static func run(activityID: Int) async {
        let authManager = StravaAuthManager()
        let apiClient = StravaAPIClient(authManager: authManager)

        guard let detail = try? await apiClient.fetchActivityDetail(id: activityID) else { return }

        let activitySummary = activitySummaryText(detail)
        let context = await recoveryContextText()

        guard let review = try? await WorkoutReviewClient.fetchReview(activitySummary: activitySummary, context: context) else { return }

        WorkoutReviewStore.shared.save(
            WorkoutReview(activityID: activityID, activityName: detail.name, text: review, generatedAt: Date())
        )
        await postNotification(activityName: detail.name, review: review)
    }

    private static func activitySummaryText(_ detail: StravaActivityDetail) -> String {
        var parts = ["\(detail.type) — \(detail.name)"]
        if detail.distance > 0 {
            parts.append(Units.formattedMiles(detail.distance))
        }
        parts.append("\(detail.movingTime / 60) min")
        if detail.totalElevationGain > 0 {
            parts.append("\(Units.formattedFeet(detail.totalElevationGain)) gain")
        }
        if let heartrate = detail.averageHeartrate, heartrate > 0 {
            parts.append("\(String(format: "%.0f", heartrate)) bpm avg")
        }
        if detail.deviceWatts == true, let watts = detail.weightedAverageWatts ?? detail.averageWatts {
            parts.append("\(String(format: "%.0f", watts))w avg")
        }
        if let effort = detail.sufferScore, effort > 0 {
            parts.append("relative effort \(String(format: "%.0f", effort))")
        }
        return parts.joined(separator: ", ")
    }

    /// Best-effort recovery/training-load snapshot from whatever's
    /// available on-device — HealthKit authorization and intervals.icu are
    /// both optional, so this silently omits whatever isn't connected
    /// rather than failing the whole review.
    private static func recoveryContextText() async -> String {
        async let sleep = try? HealthKitManager.fetchLastNightSleepHours()
        async let restingHR = try? HealthKitManager.fetchLatestQuantitySample(
            for: .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: .minute())
        )
        async let hrv = try? HealthKitManager.fetchLatestQuantitySample(
            for: .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli)
        )

        var lines: [String] = []
        if let sleep = await sleep {
            lines.append("Sleep last night: \(String(format: "%.1f", sleep)) h")
        }
        if let restingHR = await restingHR {
            lines.append("Resting heart rate: \(String(format: "%.0f", restingHR)) bpm")
        }
        if let hrv = await hrv {
            lines.append("HRV: \(String(format: "%.0f", hrv)) ms")
        }

        if let credentials = KeychainStore.loadIntervalsCredentials() {
            let client = IntervalsICUAPIClient(credentials: credentials)
            if let wellness = try? await client.fetchWellness(sinceDays: 7),
               let latest = wellness.sorted(by: { $0.id < $1.id }).last,
               let ctl = latest.ctl, let atl = latest.atl {
                lines.append("Fitness (CTL): \(String(format: "%.0f", ctl)), Fatigue (ATL): \(String(format: "%.0f", atl)), Form: \(String(format: "%.0f", ctl - atl))")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func postNotification(activityName: String, review: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Workout Review: \(activityName)"
        content.body = review
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
