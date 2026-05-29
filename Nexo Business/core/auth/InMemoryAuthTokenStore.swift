//
//  InMemoryAuthTokenStore.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public actor InMemoryAuthTokenStore: AuthTokenStoring {
    private var stored: AuthTokens?

    public init(tokens: AuthTokens? = nil) {
        self.stored = tokens
    }

    public func tokens() async -> AuthTokens? {
        stored
    }

    public func accessToken() async -> String? {
        stored?.accessToken
    }

    public func save(tokens: AuthTokens) async throws {
        stored = tokens
    }

    public func clear() async throws {
        stored = nil
    }
}
