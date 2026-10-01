import Foundation
import Security

enum KeychainStore {
    private static let service = "com.solodev.MacToFind"
    private static let account = "gemini_api_key"

    static var geminiAPIKey: String {
        get {
            if let key = read() { return key }
            // One-time migration from the old plain-text UserDefaults storage.
            if let legacy = UserDefaults.standard.string(forKey: account), !legacy.isEmpty {
                write(legacy)
                UserDefaults.standard.removeObject(forKey: account)
                return legacy
            }
            return ""
        }
        set { newValue.isEmpty ? delete() : write(newValue) }
    }

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    private static func read() -> String? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func write(_ value: String) {
        let data = Data(value.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var q = query
            q[kSecValueData as String] = data
            SecItemAdd(q as CFDictionary, nil)
        }
    }

    private static func delete() {
        SecItemDelete(query as CFDictionary)
    }
}
