import Combine
import Foundation

@MainActor
final class CoachChatViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isSending = false
    @Published var errorMessage: String?

    private let dashboardViewModel: DashboardViewModel

    init(dashboardViewModel: DashboardViewModel) {
        self.dashboardViewModel = dashboardViewModel
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        messages.append(ChatMessage(role: .user, content: trimmed))
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            let reply = try await CoachChatClient.send(
                messages: messages,
                context: dashboardViewModel.trainingSummaryText()
            )
            messages.append(reply)
        } catch {
            errorMessage = "Couldn't reach your coach: \(error.localizedDescription)"
        }
    }
}
