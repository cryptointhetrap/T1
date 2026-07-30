import Combine
import Foundation

@MainActor
final class CoachChatViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isSending = false
    @Published var errorMessage: String?

    private let dashboardViewModel: DashboardViewModel
    private let scheduledWorkoutStore: ScheduledWorkoutStore

    init(dashboardViewModel: DashboardViewModel, scheduledWorkoutStore: ScheduledWorkoutStore) {
        self.dashboardViewModel = dashboardViewModel
        self.scheduledWorkoutStore = scheduledWorkoutStore
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        messages.append(ChatMessage(role: .user, content: trimmed))
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            let context = dashboardViewModel.trainingSummaryText() + "\n\n" + scheduleContextText()
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
                    "- id \(workout.id.uuidString), \(Self.dateFormatter.string(from: workout.date)), " +
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
                guard let dateString = action.date, let date = Self.parseDate(dateString) else { continue }
                scheduledWorkoutStore.add(
                    date: date,
                    sport: action.sport ?? "Other",
                    title: action.title ?? "Workout",
                    notes: action.notes ?? ""
                )
            case "update":
                guard let idString = action.id, let id = UUID(uuidString: idString) else { continue }
                scheduledWorkoutStore.update(
                    id: id,
                    date: action.date.flatMap(Self.parseDate),
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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func parseDate(_ string: String) -> Date? {
        dateFormatter.date(from: string)
    }
}
