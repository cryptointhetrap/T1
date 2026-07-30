import Combine
import Foundation

/// Persists scheduled (future) workouts to a JSON file on-device. There is
/// no backend involved — Strava has no concept of a planned-but-not-yet-
/// done workout, so this is the app's own source of truth, mutated either
/// by the athlete directly or by actions the coach chat proposes.
@MainActor
final class ScheduledWorkoutStore: ObservableObject {
    @Published private(set) var workouts: [ScheduledWorkout] = []

    /// Optional — when set (i.e. the athlete has connected Google
    /// Calendar), mutations are best-effort mirrored as calendar events.
    /// Failures are swallowed; the local schedule stays the source of
    /// truth regardless of whether the mirrored event succeeds.
    var googleCalendarClient: GoogleCalendarAPIClient?

    private let fileURL: URL
    private let calendar = Calendar.current

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("scheduled_workouts.json")
        load()
    }

    func workouts(on day: Date) -> [ScheduledWorkout] {
        workouts.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    @discardableResult
    func add(date: Date, sport: String, title: String, notes: String) -> ScheduledWorkout {
        let workout = ScheduledWorkout(date: date, sport: sport, title: title, notes: notes)
        workouts.append(workout)
        save()
        syncCreate(workout)
        return workout
    }

    func update(id: UUID, date: Date?, sport: String?, title: String?, notes: String?) {
        guard let index = workouts.firstIndex(where: { $0.id == id }) else { return }
        if let date { workouts[index].date = date }
        if let sport { workouts[index].sport = sport }
        if let title { workouts[index].title = title }
        if let notes { workouts[index].notes = notes }
        save()
        syncUpdate(workouts[index])
    }

    func delete(id: UUID) {
        guard let workout = workouts.first(where: { $0.id == id }) else { return }
        workouts.removeAll { $0.id == id }
        save()
        syncDelete(workout)
    }

    private func setGoogleEventID(id: UUID, eventID: String) {
        guard let index = workouts.firstIndex(where: { $0.id == id }) else { return }
        workouts[index].googleEventID = eventID
        save()
    }

    private func syncCreate(_ workout: ScheduledWorkout) {
        guard let client = googleCalendarClient else { return }
        Task {
            if let eventID = try? await client.createEvent(for: workout) {
                setGoogleEventID(id: workout.id, eventID: eventID)
            }
        }
    }

    private func syncUpdate(_ workout: ScheduledWorkout) {
        guard let client = googleCalendarClient, let eventID = workout.googleEventID else { return }
        Task { try? await client.updateEvent(eventID: eventID, workout: workout) }
    }

    private func syncDelete(_ workout: ScheduledWorkout) {
        guard let client = googleCalendarClient, let eventID = workout.googleEventID else { return }
        Task { try? await client.deleteEvent(eventID: eventID) }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        workouts = (try? JSONDecoder().decode([ScheduledWorkout].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(workouts) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
