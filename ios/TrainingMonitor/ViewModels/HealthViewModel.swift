import Combine
import Foundation
import HealthKit

@MainActor
final class HealthViewModel: ObservableObject {
    @Published private(set) var isAuthorized = false
    @Published private(set) var sleepHours: Double?
    @Published private(set) var restingHeartRate: Double?
    @Published private(set) var heartRateVariability: Double?
    @Published var errorMessage: String?

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
        async let sleep = try? HealthKitManager.fetchLastNightSleepHours()
        async let restingHR = try? HealthKitManager.fetchLatestQuantitySample(
            for: .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: .minute())
        )
        async let hrv = try? HealthKitManager.fetchLatestQuantitySample(
            for: .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli)
        )
        sleepHours = await sleep
        restingHeartRate = await restingHR
        heartRateVariability = await hrv
    }

    /// Plain-text recovery summary, appended to the coach chat's context so
    /// Claude's suggestions can factor in sleep/recovery.
    func summaryText() -> String {
        guard isAuthorized else { return "" }

        var lines: [String] = []
        if let sleepHours { lines.append("Last night's sleep: \(String(format: "%.1f", sleepHours)) h") }
        if let restingHeartRate { lines.append("Resting heart rate: \(String(format: "%.0f", restingHeartRate)) bpm") }
        if let heartRateVariability { lines.append("Heart rate variability (SDNN): \(String(format: "%.0f", heartRateVariability)) ms") }

        guard !lines.isEmpty else { return "" }
        return "Recovery (Apple Health):\n" + lines.joined(separator: "\n")
    }
}
