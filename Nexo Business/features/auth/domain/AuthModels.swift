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
