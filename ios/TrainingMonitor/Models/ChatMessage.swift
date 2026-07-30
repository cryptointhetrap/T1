import Foundation

enum ChatRole: String, Codable {
    case user
    case assistant
}

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: ChatRole
    let content: String

    init(role: ChatRole, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
    }
}
