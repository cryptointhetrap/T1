import Combine
import Foundation

struct WorkoutReview: Codable, Identifiable {
    let activityID: Int
    let activityName: String
    let text: String
    let generatedAt: Date

    var id: Int { activityID }
}

/// AI-generated post-workout reviews (`WorkoutReviewGenerator`), persisted
/// on-device so they survive past the local notification that first
/// delivered them and can be reread later from the Stats tab's activity
/// list (`ActivityRow`). A singleton rather than threaded through every
/// view that might show one, since it's simple global state, not
/// request-scoped — same idea as `Color.ghGreen`.
@MainActor
final class WorkoutReviewStore: ObservableObject {
    static let shared = WorkoutReviewStore()

    @Published private(set) var reviews: [Int: WorkoutReview] = [:] {
        didSet {
            guard let data = try? JSONEncoder().encode(reviews) else { return }
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    private static let key = "com.trainingmonitor.app.workout-reviews"
    /// Bounds on-device storage to the most recent reviews.
    private static let maxStored = 30

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([Int: WorkoutReview].self, from: data) {
            reviews = decoded
        }
    }

    func review(for activityID: Int) -> WorkoutReview? {
        reviews[activityID]
    }

    func save(_ review: WorkoutReview) {
        reviews[review.activityID] = review
        guard reviews.count > Self.maxStored else { return }
        let stale = reviews.values.sorted { $0.generatedAt < $1.generatedAt }.prefix(reviews.count - Self.maxStored)
        for review in stale {
            reviews.removeValue(forKey: review.activityID)
        }
    }
}
