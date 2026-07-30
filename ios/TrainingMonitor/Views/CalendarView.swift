import SwiftUI

struct CalendarView: View {
    @StateObject private var viewModel: CalendarViewModel
    @State private var selectedDay: SelectedDay?

    init(viewModel: CalendarViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 24) {
                    ForEach(viewModel.months) { month in
                        MonthGridView(
                            month: month,
                            activities: viewModel.activities(on:),
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
                DayActivitiesView(day: selected.date, activities: viewModel.activities(on: selected.date))
            }
        }
    }
}

private struct SelectedDay: Identifiable {
    let date: Date
    var id: Date { date }
}
