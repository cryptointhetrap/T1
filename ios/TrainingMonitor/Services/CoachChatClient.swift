import Foundation

/// One schedule change the coach proposed, mirroring the backend's
/// structured-output schema. `id` identifies an existing `ScheduledWorkout`
/// for "update"/"delete"; it's absent for "add".
struct ScheduledWorkoutAction: Codable {
    let type: String
    let id: String?
    let date: String?
    let time: String?
    let sport: String?
    let title: String?
    let notes: String?
}

struct CoachChatResult {
    let message: ChatMessage
    let actions: [ScheduledWorkoutAction]
}

/// Talks to our backend's /chat/coach endpoint, which holds the Anthropic
/// API key and forwards the conversation to Claude. The app never talks to
/// Anthropic directly.
enum CoachChatClient {
    enum ChatError: Error {
        case server(String)
        case invalidResponse
    }

    private struct WireMessage: Codable {
        let role: String
        let content: String
    }

    private struct ChatRequest: Codable {
        let messages: [WireMessage]
        let context: String
    }

    private struct ChatResponse: Codable {
        let role: String
        let content: String
        let actions: [ScheduledWorkoutAction]
    }

    static func send(messages: [ChatMessage], context: String) async throws -> CoachChatResult {
        var request = URLRequest(url: AppConfig.backendBaseURL.appendingPathComponent("chat/coach"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ChatRequest(
                messages: messages.map { WireMessage(role: $0.role.rawValue, content: $0.content) },
                context: context
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ChatError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw ChatError.server(message ?? "Backend returned status \(http.statusCode)")
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        let role = ChatRole(rawValue: decoded.role) ?? .assistant
        return CoachChatResult(
            message: ChatMessage(role: role, content: decoded.content),
            actions: decoded.actions
        )
    }
}
