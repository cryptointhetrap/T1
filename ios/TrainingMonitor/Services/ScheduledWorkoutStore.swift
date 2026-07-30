import Combine
import Foundation

/// Persists scheduled (future) workouts to a JSON file on-device. There is
/// no backend involved — Strava has no concept of a planned-but-not-yet-
/// done workout, so this is the app's own source of truth, mutated either
/// by the athlete directly or by actions the coach chat proposes.
@MainActor
final class ScheduledWorkoutStore: ObservableObject {
    @Published private(set) var workouts: [ScheduledWorkout] = []

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
        let workout = ScheduledWorkout(date: calendar.startOfDay(for: date), sport: sport, title: title, notes: notes)
        workouts.append(workout)
        save()
        return workout
    }

    func update(id: UUID, date: Date?, sport: String?, title: String?, notes: String?) {
        guard let index = workouts.firstIndex(where: { $0.id == id }) else { return }
        if let date { workouts[index].date = calendar.startOfDay(for: date) }
        if let sport { workouts[index].sport = sport }
        if let title { workouts[index].title = title }
        if let notes { workouts[index].notes = notes }
        save()
    }

    func delete(id: UUID) {
        workouts.removeAll { $0.id == id }
        save()
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
