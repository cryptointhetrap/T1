import Foundation

/// Calls the backend's `/chat/motivation` endpoint — see
/// `backend/src/routes/chat.ts`. Returns a single original motivational
/// line, not a quote attributed to any real person.
enum MotivationClient {
    enum APIError: Error {
        case requestFailed(Int)
    }

    private struct Response: Decodable {
        let quote: String
    }

    static func fetchQuote() async throws -> String {
        let url = AppConfig.backendBaseURL.appendingPathComponent("chat/motivation")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(Response.self, from: data).quote
    }
}
