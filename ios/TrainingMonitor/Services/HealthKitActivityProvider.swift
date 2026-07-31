import Foundation
import HealthKit

/// The Apple Health Workouts alternative to `StravaAPIClient` for
/// athletes without a Strava account — see `ActivitySourceStore`.
struct HealthKitActivityProvider: ActivityProvider {
    func fetchActivities(after: Date, before: Date?) async throws -> [StravaActivity] {
        let workouts = try await HealthKitManager.fetchWorkouts(after: after, before: before ?? Date())
        return workouts.map(StravaActivity.init(workout:))
    }
}

extension StravaActivity {
    /// Synthesizes a `StravaActivity` from an Apple Health workout, so the
    /// same dashboard/calendar/coach pipeline works whether the athlete
    /// connected Strava or chose Apple Health Workouts instead. HealthKit
    /// gives a much thinner slice than Strava — no power data, relative
    /// effort, or all-time PR ranking — so those fields are left
    /// `nil`/`false`, and the sections that only render when they're
    /// present (aerobic efficiency trend, Recent PRs, wattage) simply
    /// don't show up for this source.
    init(workout: HKWorkout) {
        let type = HealthKitManager.activityTypeName(workout.workoutActivityType)
        let distanceMeters = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
        let movingSeconds = Int(workout.duration)

        id = workout.uuid.hashValue
        name = HealthKitManager.displayName(type: type, date: workout.startDate)
        self.type = type
        distance = distanceMeters
        movingTime = movingSeconds
        elapsedTime = movingSeconds
        totalElevationGain = (workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity)?.doubleValue(for: .meter()) ?? 0
        startDateLocal = workout.startDate
        averageHeartrate = nil
        averageSpeed = distanceMeters > 0 && movingSeconds > 0 ? distanceMeters / Double(movingSeconds) : nil
        averageWatts = nil
        weightedAverageWatts = nil
        deviceWatts = nil
        kilojoules = nil
        sufferScore = nil
    }
}
