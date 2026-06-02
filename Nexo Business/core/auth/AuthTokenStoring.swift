//
//  AuthTokenStoring.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

protocol AuthTokenStoring: Sendable {
    func tokens() async -> AuthTokens?
    func accessToken() async -> String?
    func save(tokens: AuthTokens) async throws
    func clear() async throws
}
