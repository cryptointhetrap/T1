import Foundation

/// Registers/unregisters this device's APNs token with the backend
/// (`PUT`/`DELETE /push/:athleteID/token` — see
/// `backend/src/routes/push.ts`), so it knows where to send a silent push
/// when a new Strava activity syncs for this athlete. Best-effort, same as
/// the group-stats push elsewhere — a failed registration just means no
/// workout-review push until the next successful one.
enum PushRegistrationClient {
    static func register(athleteID: Int, deviceToken: String) async {
        let url = AppConfig.backendBaseURL.appendingPathComponent("push/\(athleteID)/token")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "deviceToken": deviceToken,
            "environment": environment,
        ])
        _ = try? await URLSession.shared.data(for: request)
    }

    static func unregister(athleteID: Int) async {
        let url = AppConfig.backendBaseURL.appendingPathComponent("push/\(athleteID)/token")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try? await URLSession.shared.data(for: request)
    }
}
