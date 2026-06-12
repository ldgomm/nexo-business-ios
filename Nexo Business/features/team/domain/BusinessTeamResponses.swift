//
//  BusinessTeamResponses.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import Foundation

struct BusinessTeamUsersResponse: Decodable, Equatable, Sendable {
    let users: [BusinessTeamUser]
}

struct BusinessTeamUserEnvelope: Decodable, Equatable, Sendable {
    let user: BusinessTeamUser
}

struct BusinessTeamRolesResponse: Decodable, Equatable, Sendable {
    let roles: [BusinessTeamRole]
}

struct BusinessTeamRoleEnvelope: Decodable, Equatable, Sendable {
    let role: BusinessTeamRole
}

struct BusinessTeamPermissionsResponse: Decodable, Equatable, Sendable {
    let permissions: [BusinessTeamPermission]
}

struct BusinessTeamBranchesResponse: Decodable, Equatable, Sendable {
    let branches: [BusinessTeamBranch]
}

struct BusinessTeamTemporaryUserResponse: Decodable, Equatable, Sendable {
    let user: BusinessTeamUser
    let credentialId: String?
    let membershipId: String?
    let temporaryPassword: String
    let mustChangePassword: Bool
    let createdAt: Date
}
