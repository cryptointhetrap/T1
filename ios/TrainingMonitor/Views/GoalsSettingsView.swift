import SwiftUI

/// Lets the athlete set (or clear) weekly distance/time/elevation targets,
/// shown as progress rings on the Stats tab (`WeeklyGoalRings`). Each field
/// is independent — leave any blank to skip that ring entirely.
struct GoalsSettingsView: View {
    @ObservedObject var store: GoalsStore
    @Environment(\.dismiss) private var dismiss

    @State private var distanceText: String
    @State private var timeText: String
    @State private var elevationText: String

    init(store: GoalsStore) {
        self.store = store
        _distanceText = State(initialValue: Self.text(for: store.goals.distanceMiles))
        _timeText = State(initialValue: Self.text(for: store.goals.timeHours))
        _elevationText = State(initialValue: Self.text(for: store.goals.elevationFeet))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    goalField("Distance", text: $distanceText, unit: "mi")
                    goalField("Time", text: $timeText, unit: "h")
                    goalField("Elevation", text: $elevationText, unit: "ft")
                } header: {
                    Text("Weekly targets")
                } footer: {
                    Text("Leave a field blank to skip its ring. Progress is measured against the current calendar week, same as the Stats tab's \"This week\" numbers.")
                }
            }
            .navigationTitle("Weekly Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.goals = WeeklyGoals(
                            distanceMiles: Double(distanceText),
                            timeHours: Double(timeText),
                            elevationFeet: Double(elevationText)
                        )
                        dismiss()
                    }
                }
            }
        }
    }

    private func goalField(_ title: String, text: Binding<String>, unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("Optional", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }

    private static func text(for value: Double?) -> String {
        value.map { String(format: "%.0f", $0) } ?? ""
    }
}
