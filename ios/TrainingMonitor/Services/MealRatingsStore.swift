import Combine
import Foundation

enum MealRating {
    case up
    case down
}

/// Tracks which meal suggestions the athlete has rated 👍/👎, persisted
/// on-device (capped, newest first). Sent as plain-text context on every
/// `/chat/meals` call (see `MealsClient`/`MealsViewModel`) so tomorrow's
/// suggestions lean toward liked patterns and away from disliked ones —
/// this is how the tab "learns" preferences over time without any backend
/// state, consistent with the rest of this app's stateless-backend design.
@MainActor
final class MealRatingsStore: ObservableObject {
    @Published private(set) var liked: [String]
    @Published private(set) var disliked: [String]

    private static let likedKey = "com.trainingmonitor.app.meal-ratings-liked"
    private static let dislikedKey = "com.trainingmonitor.app.meal-ratings-disliked"
    private static let maxEntries = 40

    init() {
        liked = UserDefaults.standard.stringArray(forKey: Self.likedKey) ?? []
        disliked = UserDefaults.standard.stringArray(forKey: Self.dislikedKey) ?? []
    }

    func rating(for name: String) -> MealRating? {
        if liked.contains(name) { return .up }
        if disliked.contains(name) { return .down }
        return nil
    }

    /// Tapping the same thumb again clears the rating; tapping the other
    /// thumb moves it from one list to the other.
    func toggle(_ name: String, _ rating: MealRating) {
        let isAlreadySet = self.rating(for: name) == rating
        liked.removeAll { $0 == name }
        disliked.removeAll { $0 == name }

        if !isAlreadySet {
            switch rating {
            case .up: liked.insert(name, at: 0)
            case .down: disliked.insert(name, at: 0)
            }
            liked = Array(liked.prefix(Self.maxEntries))
            disliked = Array(disliked.prefix(Self.maxEntries))
        }

        UserDefaults.standard.set(liked, forKey: Self.likedKey)
        UserDefaults.standard.set(disliked, forKey: Self.dislikedKey)
    }
}
