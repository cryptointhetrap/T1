import Foundation

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
    }

    static func send(messages: [ChatMessage], context: String) async throws -> ChatMessage {
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
        return ChatMessage(role: role, content: decoded.content)
    }
}
