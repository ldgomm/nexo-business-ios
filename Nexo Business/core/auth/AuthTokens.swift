//
//  AuthTokens.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

struct AuthTokens: Equatable, Codable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?

    init(
        accessToken: String,
        refreshToken: String? = nil,
        expiresAt: Date? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }
}
