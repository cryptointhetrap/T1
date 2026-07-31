import Combine
import Foundation

struct CalendarMonth: Identifiable, Equatable {
    let id: Date // first of month
    var monthStart: Date { id }
}

@MainActor
final class CalendarViewModel: ObservableObject {
    /// Months rendered so far, most recent first. New (older) months are
    /// appended as the user scrolls down — there's no lower bound, so this
    /// can grow back through the athlete's entire Strava history.
    @Published private(set) var months: [CalendarMonth] = []
    @Published private(set) var activitiesByDay: [Date: [StravaActivity]] = [:]
    @Published private(set) var loadingMonths: Set<Date> = []
    @Published var errorMessage: String?

    private var loadedMonths: Set<Date> = []
    private let activityProvider: ActivityProvider
    private let calendar = Calendar.current

    init(activityProvider: ActivityProvider) {
        self.activityProvider = activityProvider

        let currentMonthStart = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        months = (0..<3).compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: currentMonthStart)
        }.map(CalendarMonth.init)
    }

    func activities(on day: Date) -> [StravaActivity] {
        activitiesByDay[calendar.startOfDay(for: day)] ?? []
    }

    /// Appends the next (older) month once the currently-oldest loaded
    /// month scrolls into view. This is what makes the calendar scroll back
    /// indefinitely instead of stopping at a fixed window.
    func loadOlderMonthIfNeeded(currentlyShowing month: CalendarMonth) {
        guard month.id == months.last?.id else { return }
        guard let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: month.monthStart) else { return }
        months.append(CalendarMonth(id: previousMonthStart))
    }

    func loadIfNeeded(month: CalendarMonth) async {
        guard !loadedMonths.contains(month.id), !loadingMonths.contains(month.id) else { return }

        loadingMonths.insert(month.id)
        defer {
            loadingMonths.remove(month.id)
            loadedMonths.insert(month.id)
        }

        guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: month.monthStart) else { return }

        do {
            let activities = try await activityProvider.fetchActivities(after: month.monthStart, before: monthEnd)
            var grouped = activitiesByDay
            for activity in activities {
                let day = calendar.startOfDay(for: activity.startDateLocal)
                grouped[day, default: []].append(activity)
            }
            activitiesByDay = grouped
        } catch {
            errorMessage = "Couldn't load activities for \(month.monthStart.formatted(.dateTime.month().year())): \(error.localizedDescription)"
        }
    }
}
