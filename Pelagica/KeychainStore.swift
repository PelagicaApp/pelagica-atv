//
//  KeychainStore.swift
//  Pelagica
//

import Foundation
import Security

/// Stores Jellyfin access tokens in the Keychain, keyed by server URL.
struct KeychainStore {
    private let service = "app.pelagica.atv.Pelagica.accessToken"

    func saveToken(_ token: String, forServer url: URL) {
        let account = url.absoluteString
        deleteToken(forServer: url)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(token.utf8),
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func readToken(forServer url: URL) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: url.absoluteString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteToken(forServer url: URL) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: url.absoluteString,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
