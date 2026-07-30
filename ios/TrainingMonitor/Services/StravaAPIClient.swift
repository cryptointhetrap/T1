import Foundation

/// Calls the Strava API directly using the athlete's access token. The
/// backend is only ever involved in the OAuth handshake and token refresh.
final class StravaAPIClient {
    enum APIError: Error {
        case notAuthenticated
        case requestFailed(Int)
    }

    private let authManager: StravaAuthManager
    private let baseURL = URL(string: "https://www.strava.com/api/v3")!

    init(authManager: StravaAuthManager) {
        self.authManager = authManager
    }

    /// Fetches activities starting from `after` (and, if given, strictly
    /// before `before`) up to `perPage` per page, following pagination until
    /// a short page is returned. Passing a narrow `after`/`before` range
    /// (e.g. one calendar month) is how the calendar screen pages
    /// arbitrarily far into the past without ever fetching the athlete's
    /// entire history at once.
    func fetchActivities(after: Date, before: Date? = nil, perPage: Int = 100) async throws -> [StravaActivity] {
        var all: [StravaActivity] = []
        var page = 1

        while true {
            var query = [
                URLQueryItem(name: "after", value: String(Int(after.timeIntervalSince1970))),
                URLQueryItem(name: "per_page", value: String(perPage)),
                URLQueryItem(name: "page", value: String(page)),
            ]
            if let before {
                query.append(URLQueryItem(name: "before", value: String(Int(before.timeIntervalSince1970))))
            }

            let pageResults: [StravaActivity] = try await get(path: "athlete/activities", query: query)
            all.append(contentsOf: pageResults)
            if pageResults.count < perPage { break }
            page += 1
        }

        return all
    }

    private func get<T: Decodable>(path: String, query: [URLQueryItem]) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = query

        let token = try await authManager.validAccessToken()
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.requestFailed(-1) }
        guard (200..<300).contains(http.statusCode) else { throw APIError.requestFailed(http.statusCode) }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = StravaAPIClient.isoFormatterWithFractionalSeconds.date(from: string) {
                return date
            }
            if let date = StravaAPIClient.isoFormatter.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized date: \(string)")
        }
        return try decoder.decode(T.self, from: data)
    }

    private static let isoFormatter: ISO8601DateFormatter = ISO8601DateFormatter()
    private static let isoFormatterWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
