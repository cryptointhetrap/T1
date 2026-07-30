import Foundation

/// Which group (if any) this device has joined, and the display name to
/// show there — neither is sensitive, so plain `UserDefaults`.
enum GroupMembershipStore {
    private static let codeKey = "com.trainingmonitor.app.joined-group-code"
    private static let nameKey = "com.trainingmonitor.app.group-display-name"

    static var joinedCode: String? {
        get { UserDefaults.standard.string(forKey: codeKey) }
        set { UserDefaults.standard.set(newValue, forKey: codeKey) }
    }

    static var displayName: String {
        get { UserDefaults.standard.string(forKey: nameKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: nameKey) }
    }
}
