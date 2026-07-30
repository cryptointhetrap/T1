import SwiftUI

struct ActivityRow: View {
    let activity: StravaActivity

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.name)
                    .font(.subheadline.bold())
                Text("\(activity.type) · \(Units.formattedMiles(activity.distance)) · \(activity.movingTime / 60) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}
