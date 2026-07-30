import Combine
import Foundation

@MainActor
final class GroupCompareViewModel: ObservableObject {
    @Published private(set) var group: TrainingGroup?
    @Published var displayName: String
    @Published var codeInput: String = ""
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    /// The athlete's own ID, needed to know which row is "you" and to
    /// join/push stats — `nil` in the rare case Strava hasn't given us
    /// one yet (see `StravaAuthManager.validAccessToken`'s doc comment).
    let athleteID: Int?

    private let client = GroupsAPIClient()
    private var latestStats: GroupMemberStats?

    var joinedCode: String? { GroupMembershipStore.joinedCode }

    init(athleteID: Int?) {
        self.athleteID = athleteID
        self.displayName = GroupMembershipStore.displayName
    }

    /// Called whenever the dashboard's monthly stats change, so a joined
    /// group stays current without the athlete having to do anything.
    /// Best-effort and silent — a failed background push just means the
    /// group shows slightly stale numbers until the next refresh.
    func updateStats(_ stats: GroupMemberStats) {
        latestStats = stats
        guard let athleteID, let code = joinedCode, !displayName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task { try? await client.upsertMember(code: code, athleteID: athleteID, displayName: displayName, stats: stats) }
    }

    func createGroup() async {
        guard let athleteID else {
            errorMessage = "Reconnect your Strava account first."
            return
        }
        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Enter a display name first."
            return
        }

        GroupMembershipStore.displayName = displayName
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let stats = latestStats ?? GroupMemberStats(relativeEffort: 0, hours: 0, miles: 0)
            let created = try await client.create(athleteID: athleteID, displayName: displayName, stats: stats)
            GroupMembershipStore.joinedCode = created.code
            group = created
        } catch {
            errorMessage = "Couldn't create a group: \(error.localizedDescription)"
        }
    }

    func joinGroup() async {
        guard let athleteID else {
            errorMessage = "Reconnect your Strava account first."
            return
        }
        let code = codeInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else {
            errorMessage = "Enter a group code."
            return
        }
        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Enter a display name first."
            return
        }

        GroupMembershipStore.displayName = displayName
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let stats = latestStats ?? GroupMemberStats(relativeEffort: 0, hours: 0, miles: 0)
            let joined = try await client.upsertMember(code: code, athleteID: athleteID, displayName: displayName, stats: stats)
            GroupMembershipStore.joinedCode = code
            group = joined
        } catch {
            errorMessage = "Couldn't find that group — check the code and try again."
        }
    }

    func refresh() async {
        guard let code = joinedCode else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            group = try await client.fetch(code: code)
        } catch {
            errorMessage = "Couldn't refresh the group: \(error.localizedDescription)"
        }
    }

    func leaveGroup() async {
        guard let athleteID, let code = joinedCode else { return }
        try? await client.leave(code: code, athleteID: athleteID)
        GroupMembershipStore.joinedCode = nil
        group = nil
    }
}
