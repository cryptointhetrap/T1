import Foundation

/// The athlete's own current-month numbers, pushed to a joined group so
/// friends can compare. Not tied to any one sport — relative effort and
/// hours are summed across everything logged this calendar month, and
/// miles is total distance, matching how `DashboardViewModel` computes
/// its own monthly totals.
struct GroupMemberStats: Codable, Equatable {
    let relativeEffort: Double
    let hours: Double
    let miles: Double
}

struct GroupMember: Codable, Identifiable {
    let athleteID: Int
    let displayName: String
    let relativeEffort: Double
    let hours: Double
    let miles: Double
    let updatedAt: Date

    var id: Int { athleteID }
}

/// A small, invite-code-based group of TrainingMonitor athletes comparing
/// this month's training. Not a public Strava leaderboard — Strava's API
/// doesn't allow searching or reading other athletes' data at all, so
/// this only ever includes people who've separately connected their own
/// Strava account to this app and joined with the same code.
struct TrainingGroup: Codable {
    let code: String
    let createdAt: Date
    let members: [String: GroupMember]

    var memberList: [GroupMember] { Array(members.values) }
}
