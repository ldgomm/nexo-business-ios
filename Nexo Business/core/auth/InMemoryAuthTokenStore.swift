//
//  InMemoryAuthTokenStore.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

actor InMemoryAuthTokenStore: AuthTokenStoring {
    private var stored: AuthTokens?

    init(tokens: AuthTokens? = nil) {
        self.stored = tokens
    }

    func tokens() async -> AuthTokens? {
        stored
    }

    func accessToken() async -> String? {
        stored?.accessToken
    }

    func save(tokens: AuthTokens) async throws {
        stored = tokens
    }

    func clear() async throws {
        stored = nil
    }
}
