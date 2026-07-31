import SwiftUI

struct ActivityRow: View {
    let activity: StravaActivity

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.name)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var subtitle: String {
        var parts = ["\(activity.type)"]
        if activity.distance > 0 {
            parts.append(Units.formattedMiles(activity.distance))
        }
        parts.append("\(activity.movingTime / 60) min")
        if activity.deviceWatts == true, let watts = activity.weightedAverageWatts ?? activity.averageWatts {
            parts.append("\(String(format: "%.0f", watts))w")
        }
        return parts.joined(separator: " · ")
    }
}
