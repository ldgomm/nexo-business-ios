//
//  KeychainAuthTokenStore.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

#if canImport(Security)
import Security
#endif

final class KeychainAuthTokenStore: AuthTokenStoring, @unchecked Sendable {
    private let service: String
    private let account: String

    init(
        service: String = "com.nexo.business.auth",
        account: String = "business-session"
    ) {
        self.service = service
        self.account = account
    }

    func tokens() async -> AuthTokens? {
        #if canImport(Security)
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }

        return try? JSONDecoder.nexoDefault.decode(AuthTokens.self, from: data)
        #else
        return nil
        #endif
    }

    func accessToken() async -> String? {
        await tokens()?.accessToken
    }

    func save(tokens: AuthTokens) async throws {
        #if canImport(Security)
        let data = try JSONEncoder.nexoDefault.encode(tokens)

        var query = baseQuery()
        SecItemDelete(query as CFDictionary)

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainTokenStoreError.unableToSave(status)
        }
        #endif
    }

    func clear() async throws {
        #if canImport(Security)
        let status = SecItemDelete(baseQuery() as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainTokenStoreError.unableToDelete(status)
        }
        #endif
    }

    #if canImport(Security)
    func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
    #endif
}

enum KeychainTokenStoreError: Error, Equatable, Sendable {
    case unableToSave(OSStatus)
    case unableToDelete(OSStatus)
}
