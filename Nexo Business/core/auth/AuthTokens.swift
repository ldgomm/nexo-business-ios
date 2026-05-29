//
//  AuthTokens.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public struct AuthTokens: Equatable, Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: Date?

    public init(
        accessToken: String,
        refreshToken: String? = nil,
        expiresAt: Date? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }
}
