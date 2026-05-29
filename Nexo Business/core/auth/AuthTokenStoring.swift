//
//  AuthTokenStoring.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public protocol AuthTokenStoring: Sendable {
    func tokens() async -> AuthTokens?
    func accessToken() async -> String?
    func save(tokens: AuthTokens) async throws
    func clear() async throws
}
