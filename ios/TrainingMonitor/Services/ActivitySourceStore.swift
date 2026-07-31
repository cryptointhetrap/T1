import Combine
import Foundation

/// Persists the athlete's choice of `ActivitySource` once they pick
/// "Use Apple Health Workouts Instead" on `ConnectStravaView` — `nil`
/// means neither has been chosen yet, so `RootView` shows that picker.
/// Not sensitive, so plain `UserDefaults`, same as `PreferencesStore`.
@MainActor
final class ActivitySourceStore: ObservableObject {
    @Published var source: ActivitySource? {
        didSet {
            guard let source, let data = try? JSONEncoder().encode(source) else {
                UserDefaults.standard.removeObject(forKey: Self.key)
                return
            }
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    private static let key = "com.trainingmonitor.app.activity-source"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(ActivitySource.self, from: data) {
            source = decoded
        } else {
            source = nil
        }
    }
}
