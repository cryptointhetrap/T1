import SwiftUI

extension SportCategory {
    var dotColor: Color {
        switch self {
        case .run: return .mdGold
        case .ride: return .mdRed
        }
    }
}

extension ScheduledWorkout {
    /// Reuses the completed-activity colors where the sport name overlaps
    /// (run/ride). Anything else (rest days, strength, etc.) uses `.primary`
    /// rather than literal black — black-on-black would vanish in dark mode.
    var dotColor: Color {
        let lowercased = sport.lowercased()
        if lowercased.contains("run") { return .mdGold }
        if lowercased.contains("ride") || lowercased.contains("bike") || lowercased.contains("cycl") { return .mdRed }
        return .primary
    }
}

struct MonthGridView: View {
    let month: CalendarMonth
    let activities: (Date) -> [StravaActivity]
    let scheduledWorkouts: (Date) -> [ScheduledWorkout]
    let onSelectDay: (Date) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(month.monthStart, format: .dateTime.month(.wide).year())
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(calendar.veryShortWeekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ForEach(0..<leadingBlankDays, id: \.self) { _ in
                    Color.clear.frame(height: 40)
                }

                ForEach(daysInMonth, id: \.self) { day in
                    DayCell(day: day, activities: activities(day), scheduledWorkouts: scheduledWorkouts(day))
                        .onTapGesture { onSelectDay(day) }
                }
            }
        }
    }

    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: month.monthStart) else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month.monthStart) }
    }

    private var leadingBlankDays: Int {
        let weekday = calendar.component(.weekday, from: month.monthStart)
        return (weekday - calendar.firstWeekday + 7) % 7
    }
}

private struct DayCell: View {
    let day: Date
    let activities: [StravaActivity]
    let scheduledWorkouts: [ScheduledWorkout]

    var body: some View {
        VStack(spacing: 3) {
            Text(day, format: .dateTime.day())
                .font(.caption)
                .foregroundStyle(isToday ? .white : .primary)
                .frame(width: 24, height: 24)
                .background(isToday ? Color.accentColor : Color.clear, in: Circle())

            HStack(spacing: 2) {
                ForEach(sportsPresent) { category in
                    Circle()
                        .fill(category.dotColor)
                        .frame(width: 5, height: 5)
                }
                ForEach(scheduledWorkouts) { workout in
                    Circle()
                        .stroke(workout.dotColor, lineWidth: 1)
                        .frame(width: 5, height: 5)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .contentShape(Rectangle())
    }

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    private var sportsPresent: [SportCategory] {
        SportCategory.allCases.filter { category in
            activities.contains { SportCategory.matching($0) == category }
        }
    }
}
