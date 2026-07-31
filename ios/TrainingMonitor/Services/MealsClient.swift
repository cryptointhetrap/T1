import Foundation

/// Calls the backend's `/chat/meals` endpoint — see
/// `backend/src/routes/chat.ts`. Returns 5 low-carb + 5 high-carb options
/// for each of breakfast/lunch/dinner (30 total), generated fresh with the
/// athlete's past thumbs up/down history as steering context.
enum MealsClient {
    enum APIError: Error {
        case requestFailed(Int)
    }

    private struct RequestBody: Encodable {
        let likedMeals: [String]
        let dislikedMeals: [String]
    }

    private struct Response: Decodable {
        let meals: DailyMeals
    }

    static func fetchMeals(likedMeals: [String], dislikedMeals: [String]) async throws -> DailyMeals {
        let url = AppConfig.backendBaseURL.appendingPathComponent("chat/meals")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RequestBody(likedMeals: likedMeals, dislikedMeals: dislikedMeals))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(Response.self, from: data).meals
    }
}
