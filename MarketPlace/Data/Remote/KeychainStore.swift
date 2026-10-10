import Foundation
import Security

// Saves the auth token in the Keychain, the safe place for secrets on iOS.
struct KeychainStore: Sendable {
    private let service = "com.vikassaini.MarketPlace"
    private let account = "authToken"

    // Returns the saved token, or nil if there is none.
    func readToken() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    // Saves the token, replacing any old one.
    func saveToken(_ token: String) throws {
        deleteToken()
        var query = baseQuery()
        query[kSecValueData as String] = Data(token.utf8)
        // Readable after first unlock, so background sync can use it.
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    // Removes the token.
    func deleteToken() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    // The Keychain fields that identify our one token item.
    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
