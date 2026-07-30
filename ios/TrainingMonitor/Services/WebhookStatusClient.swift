import Foundation

/// A cheap check against the backend's Strava webhook event cache — lets
/// the app decide whether a full Strava resync is worth doing on
/// foreground without hitting Strava's API just to find out nothing
/// changed. See `backend/src/routes/webhooks.ts` for how the timestamp
/// gets there (Strava calls the backend once per new/updated/deleted
/// activity; the backend just remembers the latest one per athlete).
enum WebhookStatusClient {
    private struct StatusResponse: Decodable {
        let latestEventAt: Int?
    }

    static func latestEventAt(athleteID: Int) async throws -> Date? {
        let url = AppConfig.backendBaseURL.appendingPathComponent("webhooks/strava/status/\(athleteID)")
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return nil
        }
        let decoded = try JSONDecoder().decode(StatusResponse.self, from: data)
        return decoded.latestEventAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }
}
