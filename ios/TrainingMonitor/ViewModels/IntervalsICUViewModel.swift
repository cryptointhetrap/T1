import Combine
import Foundation

@MainActor
final class IntervalsICUViewModel: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var latestWellness: IntervalsWellness?
    @Published var errorMessage: String?

    private(set) var client: IntervalsICUAPIClient?

    init() {
        if let credentials = KeychainStore.loadIntervalsCredentials() {
            client = IntervalsICUAPIClient(credentials: credentials)
            isConnected = true
        }
    }

    @discardableResult
    func connect(athleteID: String, apiKey: String) async -> Bool {
        let trimmedID = athleteID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty, !trimmedKey.isEmpty else {
            errorMessage = "Enter both an athlete ID and an API key."
            return false
        }

        let credentials = IntervalsICUCredentials(athleteID: trimmedID, apiKey: trimmedKey)
        let candidate = IntervalsICUAPIClient(credentials: credentials)
        do {
            try await candidate.verifyCredentials()
        } catch {
            errorMessage = "Couldn't verify that athlete ID / API key: \(error.localizedDescription)"
            return false
        }

        KeychainStore.saveIntervalsCredentials(credentials)
        client = candidate
        isConnected = true
        errorMessage = nil
        await refresh()
        return true
    }

    func disconnect() {
        KeychainStore.clearIntervalsCredentials()
        client = nil
        isConnected = false
        latestWellness = nil
    }

    /// Best-effort — a failed background refresh shouldn't interrupt the
    /// athlete with an alert, the recovery section just stays stale.
    func refresh() async {
        guard let client else { return }
        do {
            let wellness = try await client.fetchWellness(sinceDays: 7)
            latestWellness = wellness.sorted { $0.id < $1.id }.last
        } catch {
            // swallow — see doc comment above
        }
    }

    /// A compact line for the coach chat's context, so Claude can factor in
    /// intervals.icu's own fitness/fatigue model alongside Apple Health.
    func summaryText() -> String {
        guard let wellness = latestWellness else { return "" }

        var parts: [String] = []
        if let ctl = wellness.ctl, let atl = wellness.atl {
            parts.append("fitness (CTL) \(String(format: "%.0f", ctl)), fatigue (ATL) \(String(format: "%.0f", atl)), form \(String(format: "%.0f", ctl - atl))")
        }
        if let readiness = wellness.readiness {
            parts.append("readiness \(String(format: "%.0f", readiness))")
        }
        if let hrv = wellness.hrv {
            parts.append("HRV \(String(format: "%.0f", hrv)) ms")
        }
        guard !parts.isEmpty else { return "" }
        return "Intervals.icu wellness (\(wellness.id)): " + parts.joined(separator: ", ")
    }
}
