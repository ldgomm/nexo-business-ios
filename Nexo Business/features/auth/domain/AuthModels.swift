//
//  AuthModels.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public struct LoginRequest: Encodable, Sendable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

public struct LoginResponse: Decodable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: Date?
    public let user: AuthenticatedUser?
}

public struct AuthenticatedUser: Decodable, Equatable, Sendable {
    public let id: String
    public let email: String
    public let displayName: String?
}
