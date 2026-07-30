import Combine
import Foundation

@MainActor
final class CoachChatViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isSending = false
    @Published var errorMessage: String?

    private let dashboardViewModel: DashboardViewModel
    private let scheduledWorkoutStore: ScheduledWorkoutStore
    private let healthViewModel: HealthViewModel
    private let calendarViewModel: GoogleCalendarViewModel
    private let intervalsICUViewModel: IntervalsICUViewModel
    let preferencesStore: PreferencesStore

    init(
        dashboardViewModel: DashboardViewModel,
        scheduledWorkoutStore: ScheduledWorkoutStore,
        healthViewModel: HealthViewModel,
        calendarViewModel: GoogleCalendarViewModel,
        intervalsICUViewModel: IntervalsICUViewModel,
        preferencesStore: PreferencesStore
    ) {
        self.dashboardViewModel = dashboardViewModel
        self.scheduledWorkoutStore = scheduledWorkoutStore
        self.healthViewModel = healthViewModel
        self.calendarViewModel = calendarViewModel
        self.intervalsICUViewModel = intervalsICUViewModel
        self.preferencesStore = preferencesStore
    }

    /// Refreshes upcoming Google Calendar events and intervals.icu wellness
    /// so they're current before the athlete starts chatting. Cheap no-op
    /// for whichever of the two isn't connected.
    func refreshCalendarContext() async {
        await calendarViewModel.refresh()
        await intervalsICUViewModel.refresh()
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        messages.append(ChatMessage(role: .user, content: trimmed))
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            let context = [
                dashboardViewModel.trainingSummaryText(),
                scheduleContextText(),
                healthViewModel.summaryText(),
                intervalsICUViewModel.summaryText(),
                calendarViewModel.conflictContextText(),
                preferencesStore.summaryText(),
            ]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

            let result = try await CoachChatClient.send(messages: messages, context: context)
            apply(result.actions)
            messages.append(result.message)
        } catch {
            errorMessage = "Couldn't reach your coach: \(error.localizedDescription)"
        }
    }

    /// Today's date plus the athlete's current schedule (with IDs), so
    /// Claude can resolve relative dates ("tomorrow") and reference an
    /// existing scheduled workout when asked to move or cancel it.
    private func scheduleContextText() -> String {
        var lines = ["Today's date: \(Self.dateFormatter.string(from: Date()))"]

        let upcoming = scheduledWorkoutStore.workouts.sorted { $0.date < $1.date }
        if upcoming.isEmpty {
            lines.append("Currently scheduled workouts: none.")
        } else {
            lines.append("Currently scheduled workouts:")
            for workout in upcoming {
                let notes = workout.notes.isEmpty ? "" : " — \(workout.notes)"
                lines.append(
                    "- id \(workout.id.uuidString), \(Self.dateFormatter.string(from: workout.date)) " +
                    "\(Self.timeFormatter.string(from: workout.date)), " +
                    "\(workout.sport), \"\(workout.title)\"\(notes)"
                )
            }
        }

        return lines.joined(separator: "\n")
    }

    private func apply(_ actions: [ScheduledWorkoutAction]) {
        for action in actions {
            switch action.type {
            case "add":
                guard let dateString = action.date, let date = Self.combinedDate(dateString: dateString, timeString: action.time) else { continue }
                scheduledWorkoutStore.add(
                    date: date,
                    sport: action.sport ?? "Other",
                    title: action.title ?? "Workout",
                    notes: action.notes ?? ""
                )
            case "update":
                guard let idString = action.id, let id = UUID(uuidString: idString) else { continue }
                let newDate = Self.resolvedUpdateDate(
                    dateString: action.date,
                    timeString: action.time,
                    existing: scheduledWorkoutStore.workouts.first(where: { $0.id == id })
                )
                scheduledWorkoutStore.update(
                    id: id,
                    date: newDate,
                    sport: action.sport,
                    title: action.title,
                    notes: action.notes
                )
            case "delete":
                guard let idString = action.id, let id = UUID(uuidString: idString) else { continue }
                scheduledWorkoutStore.delete(id: id)
            default:
                break
            }
        }
    }

    /// Resolves the new date for an "update" action: a full replacement if
    /// Claude gave a new date, a same-day time change if it only gave a
    /// time, or no change at all.
    private static func resolvedUpdateDate(dateString: String?, timeString: String?, existing: ScheduledWorkout?) -> Date? {
        if let dateString {
            return combinedDate(dateString: dateString, timeString: timeString)
        }
        if let timeString, let existing {
            return combinedDate(dateString: Self.dateFormatter.string(from: existing.date), timeString: timeString)
        }
        return nil
    }

    private static func combinedDate(dateString: String, timeString: String?) -> Date? {
        guard let day = dateFormatter.date(from: dateString) else { return nil }
        let calendar = Calendar.current
        if let timeString, let time = timeFormatter.date(from: timeString) {
            let components = calendar.dateComponents([.hour, .minute], from: time)
            return calendar.date(bySettingHour: components.hour ?? 7, minute: components.minute ?? 0, second: 0, of: day)
        }
        return calendar.date(bySettingHour: 7, minute: 0, second: 0, of: day)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
