import Foundation

/// Talks to our own tiny backend, never directly to Strava's token
/// endpoint, so the Strava client secret never has to live in this app.
enum BackendClient {
    enum BackendError: Error {
        case server(String)
        case invalidResponse
    }

    static func exchange(code: String) async throws -> StravaTokenResponse {
        try await post(path: "auth/exchange", body: ["code": code])
    }

    static func refresh(refreshToken: String) async throws -> StravaTokenResponse {
        try await post(path: "auth/refresh", body: ["refresh_token": refreshToken])
    }

    private static func post(path: String, body: [String: String]) async throws -> StravaTokenResponse {
        var request = URLRequest(url: AppConfig.backendBaseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BackendError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw BackendError.server(message ?? "Backend returned status \(http.statusCode)")
        }

        let decoder = JSONDecoder()
        return try decoder.decode(StravaTokenResponse.self, from: data)
    }
}
