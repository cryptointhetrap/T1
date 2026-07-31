import Foundation
import HealthKit

/// Read-only access to Apple Health recovery metrics (sleep, resting heart
/// rate, HRV) and daily activity (steps, walking + running distance).
/// Purely on-device — HealthKit has no server component and needs no
/// backend involvement.
enum HealthKitManager {
    enum HealthKitError: Error {
        case notAvailable
    }

    private static let store = HKHealthStore()

    private static var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        if let restingHeartRate = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { types.insert(restingHeartRate) }
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(hrv) }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { types.insert(steps) }
        if let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) { types.insert(distance) }
        types.insert(HKObjectType.workoutType())
        return types
    }

    static func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthKitError.notAvailable }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    /// Total time asleep (any stage) in the last 20 hours, as a stand-in
    /// for "last night's sleep."
    static func fetchLastNightSleepHours() async throws -> Double? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let calendar = Calendar.current
        let end = Date()
        guard let start = calendar.date(byAdding: .hour, value: -20, to: end) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
                }
            }
            store.execute(query)
        }

        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
        ]
        let totalSeconds = samples
            .filter { asleepValues.contains($0.value) }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        return totalSeconds > 0 ? totalSeconds / 3600 : nil
    }

    static func fetchLatestQuantitySample(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double? {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: quantityType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (results as? [HKQuantitySample]) ?? [])
                }
            }
            store.execute(query)
        }

        return samples.first?.quantity.doubleValue(for: unit)
    }

    /// Day-bucketed sums of a cumulative quantity type (steps, distance)
    /// between `start` and `end`, keyed by the start of each day. Uses
    /// `HKStatisticsCollectionQuery` rather than summing raw samples
    /// directly — HealthKit dedupes overlapping samples from multiple
    /// sources (phone + watch, say) when computing the per-day sum, which a
    /// naive manual sum would double-count.
    static func fetchDailyQuantityTotals(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async throws -> [Date: Double] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else { return [:] }
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: start)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let collection: HKStatisticsCollection = try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchor,
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let results {
                    continuation.resume(returning: results)
                } else {
                    continuation.resume(throwing: HealthKitError.notAvailable)
                }
            }
            store.execute(query)
        }

        var result: [Date: Double] = [:]
        collection.enumerateStatistics(from: start, to: end) { stats, _ in
            guard let sum = stats.sumQuantity() else { return }
            result[calendar.startOfDay(for: stats.startDate)] = sum.doubleValue(for: unit)
        }
        return result
    }

    /// Backs `HealthKitActivityProvider`, the Apple Health Workouts
    /// alternative to Strava (see `ActivitySourceStore`). Most recent
    /// first, matching `StravaAPIClient.fetchActivities`.
    static func fetchWorkouts(after start: Date, before end: Date = Date()) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (results as? [HKWorkout]) ?? [])
                }
            }
            store.execute(query)
        }
    }

    /// Maps a workout type to the same short vocabulary
    /// `SportCategory.matching` looks for in `StravaActivity.type`
    /// ("Run", "Ride", "Swim", "WeightTraining") so By Sport totals and
    /// training load work identically regardless of activity source.
    /// Anything outside those four still shows up (weekly volume, recent
    /// activities), just not broken out by sport.
    static func activityTypeName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Run"
        case .cycling: return "Ride"
        case .swimming: return "Swim"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "WeightTraining"
        case .walking: return "Walk"
        case .hiking: return "Hike"
        case .yoga: return "Yoga"
        case .rowing: return "Row"
        case .elliptical: return "Elliptical"
        case .highIntensityIntervalTraining: return "HIIT"
        default: return "Workout"
        }
    }

    /// Apple Health workouts have no athlete-given title the way Strava
    /// activities do, so this synthesizes one the same way Apple's own
    /// Fitness app does for an unnamed workout — e.g. "Morning Run".
    static func displayName(type: String, date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        let timeOfDay: String
        switch hour {
        case 5..<12: timeOfDay = "Morning"
        case 12..<17: timeOfDay = "Afternoon"
        case 17..<21: timeOfDay = "Evening"
        default: timeOfDay = "Night"
        }
        let label = type == "WeightTraining" ? "Strength Training" : type
        return "\(timeOfDay) \(label)"
    }
}
