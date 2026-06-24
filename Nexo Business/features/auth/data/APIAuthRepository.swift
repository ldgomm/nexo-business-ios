//
//  APIAuthRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

final class APIAuthRepository: AuthRepository, @unchecked Sendable {
    private let apiClient: APIClient
    private let tokenStore: AuthTokenStoring

    init(
        apiClient: APIClient,
        tokenStore: AuthTokenStoring
    ) {
        self.apiClient = apiClient
        self.tokenStore = tokenStore
    }

    func login(
        email: String,
        password: String
    ) async throws -> LoginResponse {
        let request = try APIRequest<LoginResponse>.json(
            method: .post,
            path: "/auth/login",
            body: LoginRequest(email: email, password: password),
            requiresAuth: false
        )

        let response = try await apiClient.send(request)

        try await tokenStore.save(
            tokens: AuthTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                expiresAt: response.expiresAt
            )
        )

        return response
    }

    func recoverSessions(email: String, password: String) async throws -> LoginResponse {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = try APIRequest<RecoverSessionsResponse>.json(
            method: .post,
            path: "/auth/sessions/recover",
            body: RecoverSessionsRequest(
                email: normalizedEmail,
                password: password,
                reason: "Cerrar sesiones desde Nexo Business"
            ),
            requiresAuth: false
        )

        let response = try await apiClient.send(request)

        try await tokenStore.save(
            tokens: AuthTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                expiresAt: response.accessTokenExpiresAt
            )
        )

        return LoginResponse(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: response.accessTokenExpiresAt,
            user: AuthenticatedUser(
                id: response.userId,
                email: normalizedEmail,
                displayName: nil
            )
        )
    }

    func listSessions() async throws -> [AuthUserSession] {
        let response: AuthSessionsResponse = try await apiClient.send(
            APIRequest(method: .get, path: "/auth/sessions")
        )
        return response.sessions
    }

    func revokeSession(sessionId: String, reason: String) async throws -> RevokeAuthSessionResponse {
        try await apiClient.send(
            try APIRequest<RevokeAuthSessionResponse>.json(
                method: .post,
                path: "/auth/sessions/revoke",
                body: RevokeAuthSessionRequest(sessionId: sessionId, reason: reason)
            )
        )
    }

    func revokeAllSessions(reason: String) async throws -> RevokeAuthSessionResponse {
        try await apiClient.send(
            try APIRequest<RevokeAuthSessionResponse>.json(
                method: .post,
                path: "/auth/sessions/revoke-all",
                body: RevokeAllAuthSessionsRequest(targetUserId: nil, reason: reason)
            )
        )
    }

    func logout() async throws {
        try await tokenStore.clear()
    }
}
