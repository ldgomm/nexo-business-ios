//
//  APIAuthRepository.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public final class APIAuthRepository: AuthRepository, @unchecked Sendable {
    private let apiClient: APIClient
    private let tokenStore: AuthTokenStoring

    public init(
        apiClient: APIClient,
        tokenStore: AuthTokenStoring
    ) {
        self.apiClient = apiClient
        self.tokenStore = tokenStore
    }

    public func login(
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

    public func logout() async throws {
        try await tokenStore.clear()
    }
}
