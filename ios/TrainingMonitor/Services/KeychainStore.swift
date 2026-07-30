import Foundation
import Security

/// Stores OAuth sessions (access + refresh token) in the Keychain so they
/// survive app restarts without ever touching disk in plaintext.
enum KeychainStore {
    private static let stravaAccount = "strava-session"
    private static let googleAccount = "google-session"
    private static let service = "com.trainingmonitor.app.oauth-sessions"

    static func save(_ session: StravaSession) {
        save(session, account: stravaAccount)
    }

    static func load() -> StravaSession? {
        load(account: stravaAccount)
    }

    static func clear() {
        clear(account: stravaAccount)
    }

    static func saveGoogleSession(_ session: GoogleSession) {
        save(session, account: googleAccount)
    }

    static func loadGoogleSession() -> GoogleSession? {
        load(account: googleAccount)
    }

    static func clearGoogleSession() {
        clear(account: googleAccount)
    }

    private static func save<T: Encodable>(_ session: T, account: String) {
        guard let data = try? JSONEncoder().encode(session) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private static func load<T: Decodable>(account: String) -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func clear(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
