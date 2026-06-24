//
//  AuthRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

protocol AuthRepository: Sendable {
    func login(email: String, password: String) async throws -> LoginResponse
    func recoverSessions(email: String, password: String) async throws -> LoginResponse
    func listSessions() async throws -> [AuthUserSession]
    func revokeSession(sessionId: String, reason: String) async throws -> RevokeAuthSessionResponse
    func revokeAllSessions(reason: String) async throws -> RevokeAuthSessionResponse
    func logout() async throws
}
