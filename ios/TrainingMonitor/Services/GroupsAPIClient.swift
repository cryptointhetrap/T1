import Foundation

/// Talks to the backend's `/groups` routes — see
/// `backend/src/routes/groups.ts`. No auth beyond the invite code itself;
/// this is meant for small groups of people who know each other.
struct GroupsAPIClient {
    enum APIError: Error {
        case requestFailed(Int)
    }

    func create(athleteID: Int, displayName: String, stats: GroupMemberStats) async throws -> TrainingGroup {
        let url = AppConfig.backendBaseURL.appendingPathComponent("groups")
        return try await request(url: url, method: "POST", body: [
            "athleteID": athleteID,
            "displayName": displayName,
            "stats": Self.statsBody(stats),
        ])
    }

    func fetch(code: String) async throws -> TrainingGroup {
        let url = AppConfig.backendBaseURL.appendingPathComponent("groups/\(code)")
        return try await request(url: url, method: "GET", body: nil)
    }

    /// Both "join" and "push my latest stats" — the backend upserts.
    @discardableResult
    func upsertMember(code: String, athleteID: Int, displayName: String, stats: GroupMemberStats) async throws -> TrainingGroup {
        let url = AppConfig.backendBaseURL.appendingPathComponent("groups/\(code)/members/\(athleteID)")
        return try await request(url: url, method: "PUT", body: [
            "displayName": displayName,
            "stats": Self.statsBody(stats),
        ])
    }

    func leave(code: String, athleteID: Int) async throws {
        let url = AppConfig.backendBaseURL.appendingPathComponent("groups/\(code)/members/\(athleteID)")
        let _: TrainingGroup = try await request(url: url, method: "DELETE", body: nil)
    }

    private static func statsBody(_ stats: GroupMemberStats) -> [String: Any] {
        ["relativeEffort": stats.relativeEffort, "hours": stats.hours, "miles": stats.miles]
    }

    private func request(url: URL, method: String, body: [String: Any]?) async throws -> TrainingGroup {
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(TrainingGroup.self, from: data)
    }
}
