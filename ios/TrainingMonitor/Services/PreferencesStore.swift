import Combine
import Foundation

/// Free-text goals, constraints, and preferences the athlete types in
/// themselves — e.g. "training for a fall marathon", "only have a bike
/// trainer on weekdays", "I have a sauna for recovery". Included verbatim
/// in the coach chat's context so Claude can honor them without the app
/// needing a structured field for every possible constraint. Not
/// sensitive, so plain `UserDefaults` rather than the Keychain.
@MainActor
final class PreferencesStore: ObservableObject {
    @Published var text: String {
        didSet { UserDefaults.standard.set(text, forKey: Self.key) }
    }

    private static let key = "com.trainingmonitor.app.athlete-preferences"

    init() {
        text = UserDefaults.standard.string(forKey: Self.key) ?? ""
    }

    func summaryText() -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return "Athlete's stated goals & preferences:\n\(trimmed)"
    }
}
