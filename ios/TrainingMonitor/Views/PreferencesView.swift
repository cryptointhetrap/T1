import SwiftUI

/// A free-text box for goals, constraints, and equipment the athlete wants
/// the coach to know about — deliberately unstructured so it covers
/// anything ("training for a fall marathon", "only a trainer on
/// weekdays", "I have a sauna") without a field for every possible case.
struct PreferencesView: View {
    @ObservedObject var store: PreferencesStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $store.text)
                        .frame(minHeight: 180)
                } header: {
                    Text("Goals & preferences")
                } footer: {
                    Text("Tell your coach anything relevant: upcoming races, equipment you have or don't, recovery tools, days you can't train, injuries to work around. This is sent along with every message you send in Coach chat.")
                }
            }
            .navigationTitle("Goals & Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
