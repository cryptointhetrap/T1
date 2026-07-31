import Combine
import Foundation

/// Weekly distance/time/elevation targets the athlete sets themselves,
/// compared against `DashboardViewModel.weeklySummaries` to draw the Stats
/// tab's progress rings (`WeeklyGoalRings`). Not sensitive, so plain
/// `UserDefaults` rather than the Keychain, same as `PreferencesStore`.
@MainActor
final class GoalsStore: ObservableObject {
    @Published var goals: WeeklyGoals {
        didSet {
            guard let data = try? JSONEncoder().encode(goals) else { return }
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    private static let key = "com.trainingmonitor.app.weekly-goals"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(WeeklyGoals.self, from: data) {
            goals = decoded
        } else {
            goals = WeeklyGoals()
        }
    }
}
