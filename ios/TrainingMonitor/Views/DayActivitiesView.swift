import SwiftUI

struct DayActivitiesView: View {
    let day: Date
    let activities: [StravaActivity]
    let onDeleteScheduled: (UUID) -> Void

    @State private var scheduledWorkouts: [ScheduledWorkout]

    init(day: Date, activities: [StravaActivity], scheduledWorkouts: [ScheduledWorkout], onDeleteScheduled: @escaping (UUID) -> Void) {
        self.day = day
        self.activities = activities
        self.onDeleteScheduled = onDeleteScheduled
        _scheduledWorkouts = State(initialValue: scheduledWorkouts)
    }

    var body: some View {
        NavigationStack {
            List {
                if !scheduledWorkouts.isEmpty {
                    Section("Scheduled") {
                        ForEach(scheduledWorkouts) { workout in
                            ScheduledWorkoutRow(workout: workout)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                onDeleteScheduled(scheduledWorkouts[index].id)
                            }
                            scheduledWorkouts.remove(atOffsets: offsets)
                        }
                    }
                }

                Section("Completed") {
                    if activities.isEmpty {
                        Text("No activities on this day")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(activities) { activity in
                            ActivityRow(activity: activity)
                        }
                    }
                }
            }
            .navigationTitle(day.formatted(date: .abbreviated, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ScheduledWorkoutRow: View {
    let workout: ScheduledWorkout

    var body: some View {
        HStack {
            Circle()
                .stroke(workout.dotColor, lineWidth: 1.5)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title)
                    .font(.subheadline.bold())
                Text(workout.notes.isEmpty ? workout.sport : "\(workout.sport) · \(workout.notes)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
