import Foundation

/// Calls the backend's `/chat/workout-review` endpoint — see
/// `backend/src/routes/chat.ts`. Takes a plain-text summary of one
/// just-completed activity plus recent recovery/training context, and
/// returns a short AI-written review reacting to how the workout went in
/// light of that context.
enum WorkoutReviewClient {
    enum APIError: Error {
        case requestFailed(Int)
    }

    private struct Response: Decodable {
        let review: String
    }

    static func fetchReview(activitySummary: String, context: String) async throws -> String {
        let url = AppConfig.backendBaseURL.appendingPathComponent("chat/workout-review")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "activitySummary": activitySummary,
            "context": context,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(Response.self, from: data).review
    }
}
