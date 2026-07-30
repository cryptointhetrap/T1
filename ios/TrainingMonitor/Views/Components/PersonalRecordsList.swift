import SwiftUI

/// Lists whichever of the athlete's runs Strava currently ranks in their
/// all-time top 3 for that distance, among the recently-fetched activities
/// `DashboardViewModel.refreshPersonalRecords` looked at — see that
/// method's doc comment for why this isn't a full historical PR list.
struct PersonalRecordsList: View {
    let records: [BestEffort]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(records) { effort in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(effort.name)
                            .font(.subheadline.bold())
                        Text(effort.startDateLocal.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formattedDuration(effort.movingTime))
                            .font(.subheadline.bold())
                        Text(rankLabel(effort.prRank))
                            .font(.caption)
                            .foregroundStyle(effort.prRank == 1 ? Color.mdGold : Color.secondary)
                    }
                }
                .padding(.vertical, 6)
                if effort.id != records.last?.id {
                    Divider()
                }
            }
        }
    }

    private func rankLabel(_ rank: Int?) -> String {
        switch rank {
        case 1: return "PR"
        case 2: return "#2 all-time"
        case 3: return "#3 all-time"
        default: return "top 3"
        }
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
