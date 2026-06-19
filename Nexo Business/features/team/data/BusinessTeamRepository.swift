//
//  BusinessTeamRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import Foundation

protocol BusinessTeamRepository: Sendable {
    func listUsers(query: String?, status: String?, branchId: String?, limit: Int) async throws -> [BusinessTeamUser]
    func getUser(id: String) async throws -> BusinessTeamUser
    func createTemporaryUser(_ input: CreateBusinessTeamUserInput) async throws -> BusinessTeamTemporaryUserResponse
    func updateUser(id: String, input: UpdateBusinessTeamUserInput) async throws -> BusinessTeamUser
    func blockUser(id: String, reason: String) async throws -> BusinessTeamUser
    func unblockUser(id: String, reason: String) async throws -> BusinessTeamUser
    func resetPassword(userId: String, temporaryPassword: String?, revokeSessions: Bool, reason: String) async throws -> BusinessTeamTemporaryPasswordResult
    func revokeSessions(userId: String, reason: String) async throws -> BusinessTeamSessionRevocationResult
    func listRoles(includeSystemTemplates: Bool) async throws -> [BusinessTeamRole]
    func createRole(_ input: CreateBusinessTeamRoleInput) async throws -> BusinessTeamRole
    func createRoleFromTemplate(_ input: CreateBusinessRoleFromTemplateInput) async throws -> BusinessTeamRole
    func updateRole(id: String, input: UpdateBusinessTeamRoleInput) async throws -> BusinessTeamRole
    func activateRole(id: String, reason: String) async throws -> BusinessTeamRole
    func deactivateRole(id: String, reason: String) async throws -> BusinessTeamRole
    func listRoleTemplates(vertical: String?) async throws -> [BusinessRoleTemplate]
    func listCapabilityGroups() async throws -> [BusinessHumanCapabilityGroup]
    func listPermissions(includeReserved: Bool) async throws -> [BusinessTeamPermission]
    func listAssignablePermissions() async throws -> [BusinessTeamPermission]
    func listBranches() async throws -> [BusinessTeamBranch]
}

final class BusinessTeamAPIRepository: BusinessTeamRepository, @unchecked Sendable {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func listUsers(query: String?, status: String?, branchId: String?, limit: Int) async throws -> [BusinessTeamUser] {
        let response: BusinessTeamUsersResponse = try await apiClient.send(
            APIRequest(
                method: .get,
                path: "/api/v1/business/team/users",
                queryItems: queryItems([
                    "q": query,
                    "status": status,
                    "branchId": branchId,
                    "limit": String(limit)
                ])
            )
        )
        return response.users
    }

    func getUser(id: String) async throws -> BusinessTeamUser {
        let response: BusinessTeamUserEnvelope = try await apiClient.send(
            APIRequest(method: .get, path: "/api/v1/business/team/users/\(id)")
        )
        return response.user
    }

    func createTemporaryUser(_ input: CreateBusinessTeamUserInput) async throws -> BusinessTeamTemporaryUserResponse {
        try await apiClient.send(
            try APIRequest<BusinessTeamTemporaryUserResponse>.json(
                method: .post,
                path: "/api/v1/business/team/users/temporary",
                body: input
            )
        )
    }

    func updateUser(id: String, input: UpdateBusinessTeamUserInput) async throws -> BusinessTeamUser {
        let response: BusinessTeamUserEnvelope = try await apiClient.send(
            try APIRequest<BusinessTeamUserEnvelope>.json(
                method: .put,
                path: "/api/v1/business/team/users/\(id)",
                body: input
            )
        )
        return response.user
    }

    func blockUser(id: String, reason: String) async throws -> BusinessTeamUser {
        let response: BusinessTeamUserEnvelope = try await apiClient.send(
            try APIRequest<BusinessTeamUserEnvelope>.json(
                method: .post,
                path: "/api/v1/business/team/users/\(id)/block",
                body: ReasonRequest(reason: reason)
            )
        )
        return response.user
    }

    func unblockUser(id: String, reason: String) async throws -> BusinessTeamUser {
        let response: BusinessTeamUserEnvelope = try await apiClient.send(
            try APIRequest<BusinessTeamUserEnvelope>.json(
                method: .post,
                path: "/api/v1/business/team/users/\(id)/unblock",
                body: ReasonRequest(reason: reason)
            )
        )
        return response.user
    }

    func resetPassword(userId: String, temporaryPassword: String?, revokeSessions: Bool, reason: String) async throws -> BusinessTeamTemporaryPasswordResult {
        try await apiClient.send(
            try APIRequest<BusinessTeamTemporaryPasswordResult>.json(
                method: .post,
                path: "/api/v1/business/team/users/\(userId)/reset-password",
                body: ResetPasswordRequest(
                    temporaryPassword: temporaryPassword,
                    revokeSessions: revokeSessions,
                    reason: reason
                )
            )
        )
    }

    func revokeSessions(userId: String, reason: String) async throws -> BusinessTeamSessionRevocationResult {
        try await apiClient.send(
            try APIRequest<BusinessTeamSessionRevocationResult>.json(
                method: .post,
                path: "/api/v1/business/team/users/\(userId)/revoke-sessions",
                body: ReasonRequest(reason: reason)
            )
        )
    }

    func listRoles(includeSystemTemplates: Bool) async throws -> [BusinessTeamRole] {
        let response: BusinessTeamRolesResponse = try await apiClient.send(
            APIRequest(
                method: .get,
                path: "/api/v1/business/team/roles",
                queryItems: queryItems(["includeSystemTemplates": String(includeSystemTemplates)])
            )
        )
        return response.roles
    }

    func createRole(_ input: CreateBusinessTeamRoleInput) async throws -> BusinessTeamRole {
        let response: BusinessTeamRoleEnvelope = try await apiClient.send(
            try APIRequest<BusinessTeamRoleEnvelope>.json(
                method: .post,
                path: "/api/v1/business/team/roles",
                body: input
            )
        )
        return response.role
    }

    func createRoleFromTemplate(_ input: CreateBusinessRoleFromTemplateInput) async throws -> BusinessTeamRole {
        let response: BusinessTeamRoleEnvelope = try await apiClient.send(
            try APIRequest<BusinessTeamRoleEnvelope>.json(
                method: .post,
                path: "/api/v1/business/team/roles/from-template",
                body: input
            )
        )
        return response.role
    }

    func updateRole(id: String, input: UpdateBusinessTeamRoleInput) async throws -> BusinessTeamRole {
        let response: BusinessTeamRoleEnvelope = try await apiClient.send(
            try APIRequest<BusinessTeamRoleEnvelope>.json(
                method: .put,
                path: "/api/v1/business/team/roles/\(id)",
                body: input
            )
        )
        return response.role
    }

    func activateRole(id: String, reason: String) async throws -> BusinessTeamRole {
        let response: BusinessTeamRoleEnvelope = try await apiClient.send(
            try APIRequest<BusinessTeamRoleEnvelope>.json(
                method: .post,
                path: "/api/v1/business/team/roles/\(id)/activate",
                body: ReasonRequest(reason: reason)
            )
        )
        return response.role
    }

    func deactivateRole(id: String, reason: String) async throws -> BusinessTeamRole {
        let response: BusinessTeamRoleEnvelope = try await apiClient.send(
            try APIRequest<BusinessTeamRoleEnvelope>.json(
                method: .post,
                path: "/api/v1/business/team/roles/\(id)/deactivate",
                body: ReasonRequest(reason: reason)
            )
        )
        return response.role
    }

    func listRoleTemplates(vertical: String?) async throws -> [BusinessRoleTemplate] {
        let response: BusinessRoleTemplatesResponse = try await apiClient.send(
            APIRequest(
                method: .get,
                path: "/api/v1/business/team/role-templates",
                queryItems: queryItems(["vertical": vertical])
            )
        )
        return response.templates
    }


    func listCapabilityGroups() async throws -> [BusinessHumanCapabilityGroup] {
        let response: BusinessHumanCapabilityGroupsResponse = try await apiClient.send(
            APIRequest(method: .get, path: "/api/v1/business/team/capability-groups")
        )
        return response.groups
    }

    func listPermissions(includeReserved: Bool) async throws -> [BusinessTeamPermission] {
        let response: BusinessTeamPermissionsResponse = try await apiClient.send(
            APIRequest(
                method: .get,
                path: "/api/v1/business/team/permissions",
                queryItems: queryItems(["includeReserved": String(includeReserved)])
            )
        )
        return response.permissions
    }

    func listAssignablePermissions() async throws -> [BusinessTeamPermission] {
        try await listPermissions(includeReserved: false).filter(\.assignable)
    }

    func listBranches() async throws -> [BusinessTeamBranch] {
        []
    }

    private func queryItems(_ values: [String: String?]) -> [URLQueryItem] {
        values.compactMap { key, value in
            guard let value, !value.isEmpty else { return nil }
            return URLQueryItem(name: key, value: value)
        }
    }
}

private struct ReasonRequest: Encodable, Sendable {
    let reason: String
}

private struct ResetPasswordRequest: Encodable, Sendable {
    let temporaryPassword: String?
    let revokeSessions: Bool
    let reason: String
}
