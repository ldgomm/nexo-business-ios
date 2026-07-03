//
//  AuthModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

struct LoginRequest: Encodable, Sendable {
    let email: String
    let password: String

    init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

struct LoginResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let user: AuthenticatedUser?
}

struct AuthenticatedUser: Decodable, Equatable, Sendable {
    let id: String
    let email: String
    let displayName: String?
}


struct RecoverSessionsRequest: Encodable, Sendable {
    let email: String
    let password: String
    let reason: String
}

struct RecoverSessionsResponse: Decodable, Sendable {
    let accessToken: String
    let accessTokenExpiresAt: Date
    let refreshToken: String
    let refreshTokenExpiresAt: Date
    let sessionId: String
    let userId: String
    let mustChangePassword: Bool
    let revokedSessions: Int
    let revokedRefreshTokens: Int
}

struct AuthUserSession: Identifiable, Equatable, Decodable, Sendable {
    let id: String
    let userId: String
    let status: String
    let createdAt: Date
    let expiresAt: Date
    let lastSeenAt: Date?
    let userAgent: String?
    let ipAddress: String?
    let deviceId: String?
    let appType: String?
    let appVersion: String?
    let appBuild: String?
    let platform: String?
    let current: Bool

    var displayDeviceName: String {
        let app = appType?.trimmed.nilIfBlank ?? "Nexo Business"
        let platformText = platform?.uppercased() ?? "iOS"
        return "\(app) · \(platformText)"
    }

    var displayVersion: String {
        let version = appVersion?.trimmed.nilIfBlank
        let build = appBuild?.trimmed.nilIfBlank
        switch (version, build) {
        case let (.some(version), .some(build)):
            return "Versión \(version) (\(build))"
        case let (.some(version), .none):
            return "Versión \(version)"
        case let (.none, .some(build)):
            return "Build \(build)"
        default:
            return "Versión no disponible"
        }
    }
}

struct AuthSessionsResponse: Decodable, Sendable {
    let sessions: [AuthUserSession]
}

struct RevokeAuthSessionRequest: Encodable, Sendable {
    let sessionId: String?
    let reason: String
}

struct RevokeAllAuthSessionsRequest: Encodable, Sendable {
    let targetUserId: String?
    let reason: String
}

struct RevokeAuthSessionResponse: Decodable, Sendable {
    let revokedSessions: Int
    let revokedRefreshTokens: Int
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfBlank: String? { trimmed.isEmpty ? nil : trimmed }
}
