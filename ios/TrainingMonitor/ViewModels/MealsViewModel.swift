import Combine
import Foundation

/// Backs the Meals tab. Caches one full day's 30 suggestions per calendar
/// day (same pattern as `MotivationViewModel`) so Claude is only called
/// once daily unless the athlete taps the manual refresh button.
@MainActor
final class MealsViewModel: ObservableObject {
    @Published private(set) var meals: DailyMeals?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    let ratingsStore: MealRatingsStore

    private static let cacheKey = "com.trainingmonitor.app.meals-cache"

    private struct CachedMeals: Codable {
        let day: String
        let meals: DailyMeals
    }

    init(ratingsStore: MealRatingsStore = MealRatingsStore()) {
        self.ratingsStore = ratingsStore
        meals = Self.cachedMealsForToday()
    }

    /// Uses today's cached suggestions if there are any; otherwise fetches
    /// and caches a fresh set. Safe to call multiple times — a second call
    /// while the first is still loading, or after suggestions are already
    /// loaded, is a no-op.
    func loadIfNeeded() async {
        guard meals == nil, !isLoading else { return }
        await refresh()
    }

    /// Always fetches a new set of 30, bypassing the daily cache — used by
    /// the manual refresh button.
    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await MealsClient.fetchMeals(likedMeals: ratingsStore.liked, dislikedMeals: ratingsStore.disliked)
            meals = fetched
            Self.cache(fetched)
        } catch {
            errorMessage = "Couldn't load today's meal suggestions: \(error.localizedDescription)"
        }
    }

    private static func cachedMealsForToday() -> DailyMeals? {
        guard
            let data = UserDefaults.standard.data(forKey: cacheKey),
            let cached = try? JSONDecoder().decode(CachedMeals.self, from: data),
            cached.day == dayFormatter.string(from: Date())
        else { return nil }
        return cached.meals
    }

    private static func cache(_ meals: DailyMeals) {
        let cached = CachedMeals(day: dayFormatter.string(from: Date()), meals: meals)
        guard let data = try? JSONEncoder().encode(cached) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
