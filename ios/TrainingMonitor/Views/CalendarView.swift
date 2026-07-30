import SwiftUI

struct CalendarView: View {
    @StateObject private var viewModel: CalendarViewModel
    @ObservedObject private var scheduledWorkoutStore: ScheduledWorkoutStore
    @State private var selectedDay: SelectedDay?

    init(viewModel: CalendarViewModel, scheduledWorkoutStore: ScheduledWorkoutStore) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.scheduledWorkoutStore = scheduledWorkoutStore
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 24) {
                    ForEach(viewModel.months) { month in
                        MonthGridView(
                            month: month,
                            activities: viewModel.activities(on:),
                            scheduledWorkouts: scheduledWorkoutStore.workouts(on:),
                            onSelectDay: { selectedDay = SelectedDay(date: $0) }
                        )
                        .task { await viewModel.loadIfNeeded(month: month) }
                        .onAppear { viewModel.loadOlderMonthIfNeeded(currentlyShowing: month) }
                    }

                    if !viewModel.loadingMonths.isEmpty {
                        ProgressView()
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Calendar")
            .sheet(item: $selectedDay) { selected in
                DayActivitiesView(
                    day: selected.date,
                    activities: viewModel.activities(on: selected.date),
                    scheduledWorkouts: scheduledWorkoutStore.workouts(on: selected.date),
                    onDeleteScheduled: { scheduledWorkoutStore.delete(id: $0) }
                )
            }
        }
    }
}

private struct SelectedDay: Identifiable {
    let date: Date
    var id: Date { date }
}
