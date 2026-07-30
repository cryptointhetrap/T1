import SwiftUI

struct DayActivitiesView: View {
    let day: Date
    let activities: [StravaActivity]

    var body: some View {
        NavigationStack {
            List {
                if activities.isEmpty {
                    Text("No activities on this day")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(activities) { activity in
                        ActivityRow(activity: activity)
                    }
                }
            }
            .navigationTitle(day.formatted(date: .abbreviated, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
