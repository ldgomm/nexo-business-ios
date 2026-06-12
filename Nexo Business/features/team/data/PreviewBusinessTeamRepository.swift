//
//  PreviewBusinessTeamRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import Foundation

final class PreviewBusinessTeamRepository: BusinessTeamRepository, @unchecked Sendable {
    private let createdAt = Date().addingTimeInterval(-86_400)

    private var roles: [BusinessTeamRole] {
        [
            BusinessTeamRole(
                id: "role_super_empresa",
                code: "super_empresa",
                name: "Super Empresa",
                description: "Administra usuarios, roles y permisos dentro de la organización.",
                scopeType: "ORGANIZATION",
                rank: 900,
                permissionKeys: [
                    "business.team.users.view",
                    "business.team.users.create",
                    "business.team.users.block",
                    "business.team.users.unblock",
                    "business.team.users.reset_password",
                    "business.team.sessions.revoke",
                    "business.team.roles.view",
                    "business.team.roles.manage"
                ],
                systemRole: true,
                critical: true,
                editable: false,
                status: "ACTIVE",
                schemaVersion: 1
            ),
            BusinessTeamRole(
                id: "role_cajero",
                code: "cajero",
                name: "Cajero",
                description: "Vende, cobra y opera caja.",
                scopeType: "BRANCH",
                rank: 300,
                permissionKeys: [
                    "business.sales.create",
                    "business.sales.confirm",
                    "business.cash.view_current",
                    "business.payments.collect"
                ],
                systemRole: true,
                critical: false,
                editable: true,
                status: "ACTIVE",
                schemaVersion: 1
            ),
            BusinessTeamRole(
                id: "role_mesero",
                code: "mesero",
                name: "Mesero",
                description: "Crea ventas y toma pedidos.",
                scopeType: "BRANCH",
                rank: 200,
                permissionKeys: [
                    "business.sales.create",
                    "business.sales.view"
                ],
                systemRole: true,
                critical: false,
                editable: true,
                status: "ACTIVE",
                schemaVersion: 1
            ),
            BusinessTeamRole(
                id: "role_discount_manager",
                code: "encargado_descuentos",
                name: "Encargado de descuentos",
                description: "Puede aplicar y quitar descuentos en ventas.",
                scopeType: "ORGANIZATION",
                rank: 320,
                permissionKeys: [
                    "sales.apply_discount",
                    "sales.apply_item_discount",
                    "sales.apply_selected_items_discount",
                    "sales.apply_cart_discount",
                    "sales.remove_discount"
                ],
                systemRole: false,
                critical: false,
                editable: true,
                status: "ACTIVE",
                schemaVersion: 1
            )
        ]
    }

    private var users: [BusinessTeamUser] {
        let branchId = PreviewData.businessContext.branches.first?.id
        return [
            BusinessTeamUser(
                id: "usr_super_empresa_preview",
                email: "super@nexo.test",
                displayName: "Super Empresa Preview",
                phone: "0999999999",
                status: "ACTIVE",
                scopeType: "ORGANIZATION",
                scopeId: PreviewData.businessContext.organization.id,
                branchId: nil,
                roleIds: ["role_super_empresa"],
                roleNames: ["Super Empresa"],
                highestRank: 900,
                isOrganizationSuperAdmin: true,
                activeSessionCount: 1,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            BusinessTeamUser(
                id: "usr_cajero_preview",
                email: "cajero@nexo.test",
                displayName: "Cajero Preview",
                phone: nil,
                status: "ACTIVE",
                scopeType: "BRANCH",
                scopeId: branchId ?? PreviewData.businessContext.organization.id,
                branchId: branchId,
                roleIds: ["role_cajero"],
                roleNames: ["Cajero"],
                highestRank: 300,
                isOrganizationSuperAdmin: false,
                activeSessionCount: 1,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            BusinessTeamUser(
                id: "usr_mesero_preview",
                email: "mesero@nexo.test",
                displayName: "Mesero Preview",
                phone: nil,
                status: "BLOCKED",
                scopeType: "BRANCH",
                scopeId: branchId ?? PreviewData.businessContext.organization.id,
                branchId: branchId,
                roleIds: ["role_mesero"],
                roleNames: ["Mesero"],
                highestRank: 200,
                isOrganizationSuperAdmin: false,
                activeSessionCount: 0,
                createdAt: createdAt,
                updatedAt: Date()
            )
        ]
    }

    func listUsers(query: String?, status: String?, branchId: String?, limit: Int) async throws -> [BusinessTeamUser] {
        var result = users

        if let query = query?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
            result = result.filter {
                $0.displayName.localizedCaseInsensitiveContains(query) ||
                $0.email.localizedCaseInsensitiveContains(query)
            }
        }

        if let status = status?.trimmingCharacters(in: .whitespacesAndNewlines), !status.isEmpty {
            result = result.filter { $0.status.caseInsensitiveCompare(status) == .orderedSame }
        }

        if let branchId = branchId?.trimmingCharacters(in: .whitespacesAndNewlines), !branchId.isEmpty {
            result = result.filter { $0.branchId == branchId }
        }

        return Array(result.prefix(max(1, limit)))
    }

    func getUser(id: String) async throws -> BusinessTeamUser {
        guard let user = users.first(where: { $0.id == id }) else {
            throw PreviewBusinessTeamRepositoryError.notFound
        }
        return user
    }

    func createTemporaryUser(_ input: CreateBusinessTeamUserInput) async throws -> BusinessTeamTemporaryUserResponse {
        let selectedRoles = roles.filter { input.roleIds.contains($0.id) }
        let highestRank = selectedRoles.map(\.rank).max() ?? 100
        let user = BusinessTeamUser(
            id: "usr_preview_\(UUID().uuidString.lowercased())",
            email: input.email,
            displayName: input.displayName,
            phone: input.phone,
            status: "ACTIVE",
            scopeType: input.scopeType,
            scopeId: input.scopeId,
            branchId: input.scopeType == "BRANCH" ? input.scopeId : nil,
            roleIds: input.roleIds,
            roleNames: selectedRoles.map(\.name),
            highestRank: highestRank,
            isOrganizationSuperAdmin: false,
            activeSessionCount: 0,
            createdAt: Date(),
            updatedAt: Date()
        )

        return BusinessTeamTemporaryUserResponse(
            user: user,
            credentialId: "cred_preview",
            membershipId: "mem_preview",
            temporaryPassword: input.temporaryPassword ?? "Nexo-Preview-123",
            mustChangePassword: true,
            createdAt: Date()
        )
    }

    func updateUser(id: String, input: UpdateBusinessTeamUserInput) async throws -> BusinessTeamUser {
        let current = try await getUser(id: id)
        let selectedRoles = input.roleIds.map { roleIds in roles.filter { roleIds.contains($0.id) } }
        let nextRoleIds = input.roleIds ?? current.roleIds
        let nextRoles = selectedRoles ?? roles.filter { current.roleIds.contains($0.id) }
        let nextScopeType = input.scopeType ?? current.scopeType
        let nextScopeId = input.scopeId ?? current.scopeId

        return BusinessTeamUser(
            id: current.id,
            email: current.email,
            displayName: input.displayName ?? current.displayName,
            phone: input.clearPhone ? nil : (input.phone ?? current.phone),
            status: current.status,
            scopeType: nextScopeType,
            scopeId: nextScopeId,
            branchId: nextScopeType == "BRANCH" ? nextScopeId : nil,
            roleIds: nextRoleIds,
            roleNames: nextRoles.map(\.name),
            highestRank: nextRoles.map(\.rank).max() ?? current.highestRank,
            isOrganizationSuperAdmin: current.isOrganizationSuperAdmin,
            activeSessionCount: current.activeSessionCount,
            createdAt: current.createdAt,
            updatedAt: Date()
        )
    }

    func blockUser(id: String, reason: String) async throws -> BusinessTeamUser {
        try await user(id: id, status: "BLOCKED")
    }

    func unblockUser(id: String, reason: String) async throws -> BusinessTeamUser {
        try await user(id: id, status: "ACTIVE")
    }

    func resetPassword(userId: String, temporaryPassword: String?, revokeSessions: Bool, reason: String) async throws -> BusinessTeamTemporaryPasswordResult {
        _ = try await getUser(id: userId)
        return BusinessTeamTemporaryPasswordResult(
            userId: userId,
            temporaryPassword: temporaryPassword ?? "Nexo-Preview-123",
            mustChangePassword: true,
            revokedSessions: revokeSessions ? 1 : 0,
            changedAt: Date()
        )
    }

    func revokeSessions(userId: String, reason: String) async throws -> BusinessTeamSessionRevocationResult {
        _ = try await getUser(id: userId)
        return BusinessTeamSessionRevocationResult(
            userId: userId,
            revokedSessions: 1,
            revokedRefreshTokens: 1,
            revokedAt: Date(),
            reason: reason
        )
    }

    func listRoles(includeSystemTemplates: Bool) async throws -> [BusinessTeamRole] {
        includeSystemTemplates ? roles : roles.filter { !$0.systemRole }
    }

    func createRole(_ input: CreateBusinessTeamRoleInput) async throws -> BusinessTeamRole {
        BusinessTeamRole(
            id: "role_preview_\(UUID().uuidString.lowercased())",
            code: input.code,
            name: input.name,
            description: input.description,
            scopeType: input.scopeType,
            rank: input.rank,
            permissionKeys: input.permissionKeys,
            systemRole: false,
            critical: false,
            editable: true,
            status: "ACTIVE",
            schemaVersion: 1
        )
    }

    func createRoleFromTemplate(_ input: CreateBusinessRoleFromTemplateInput) async throws -> BusinessTeamRole {
        let template = (try await listRoleTemplates(vertical: nil)).first { $0.templateCode == input.templateCode }
        guard let template else { throw PreviewBusinessTeamRepositoryError.notFound }
        return BusinessTeamRole(
            id: "role_preview_template_\(UUID().uuidString.lowercased())",
            code: input.code ?? template.roleCode,
            name: input.name ?? template.name,
            description: input.description ?? template.description,
            scopeType: "ORGANIZATION",
            rank: template.rank,
            permissionKeys: template.permissionKeys,
            systemRole: false,
            critical: template.critical,
            editable: template.editableByBusiness,
            status: "ACTIVE",
            schemaVersion: 1
        )
    }

    func updateRole(id: String, input: UpdateBusinessTeamRoleInput) async throws -> BusinessTeamRole {
        let current = try role(id: id)
        return BusinessTeamRole(
            id: current.id,
            code: current.code,
            organizationId: current.organizationId,
            scope: current.scope,
            type: current.type,
            name: input.name ?? current.name,
            description: input.description ?? current.description,
            scopeType: current.scopeType,
            rank: input.rank ?? current.rank,
            permissionKeys: input.permissionKeys ?? current.permissionKeys,
            systemRole: current.systemRole,
            critical: current.critical,
            editable: current.editable,
            status: current.status,
            schemaVersion: current.schemaVersion + 1
        )
    }

    func activateRole(id: String, reason: String) async throws -> BusinessTeamRole {
        try role(id: id, status: "ACTIVE")
    }

    func deactivateRole(id: String, reason: String) async throws -> BusinessTeamRole {
        try role(id: id, status: "INACTIVE")
    }

    func listRoleTemplates(vertical: String?) async throws -> [BusinessRoleTemplate] {
        let templates = [
            BusinessRoleTemplate(
                templateCode: "core.discount_manager",
                vertical: "CORE",
                roleCode: "encargado_descuentos",
                name: "Encargado de descuentos",
                description: "Puede aplicar y quitar descuentos en ventas.",
                permissionKeys: ["sales.apply_discount", "sales.apply_item_discount", "sales.apply_cart_discount", "sales.remove_discount"],
                requiredModules: ["core.sales"],
                assignableByBusiness: true,
                editableByBusiness: true,
                critical: false,
                rank: 320
            ),
            BusinessRoleTemplate(
                templateCode: "restaurant.waiter",
                vertical: "RESTAURANT",
                roleCode: "mesero",
                name: "Mesero",
                description: "Puede tomar pedidos y registrar ventas.",
                permissionKeys: ["sales.view", "sales.create", "customers.view"],
                requiredModules: ["core.sales"],
                assignableByBusiness: true,
                editableByBusiness: true,
                critical: false,
                rank: 220
            )
        ]
        guard let vertical, !vertical.isEmpty else { return templates }
        return templates.filter { $0.vertical == "CORE" || $0.vertical == vertical }
    }

    func listPermissions(includeReserved: Bool) async throws -> [BusinessTeamPermission] {
        [
            BusinessTeamPermission(
                code: "business.team.users.view",
                name: "Ver usuarios",
                description: "Permite ver usuarios del negocio.",
                category: "TEAM",
                humanLabel: "Ver equipo",
                assignable: true
            ),
            BusinessTeamPermission(
                code: "business.team.users.create",
                name: "Crear usuarios",
                description: "Permite crear usuarios temporales.",
                category: "TEAM",
                humanLabel: "Crear usuarios",
                assignable: true
            ),
            BusinessTeamPermission(
                code: "business.team.roles.manage",
                name: "Administrar roles",
                description: "Permite crear y editar roles locales.",
                category: "TEAM",
                humanLabel: "Administrar roles",
                assignable: true
            ),
            BusinessTeamPermission(
                code: "platform.organizations.create",
                name: "Crear organizaciones",
                description: "Permiso reservado para plataforma.",
                category: "PLATFORM",
                humanLabel: "Crear organizaciones",
                assignable: includeReserved
            )
        ].filter { includeReserved || $0.assignable }
    }

    func listAssignablePermissions() async throws -> [BusinessTeamPermission] {
        try await listPermissions(includeReserved: false).filter(\.assignable)
    }

    func listBranches() async throws -> [BusinessTeamBranch] {
        PreviewData.businessContext.branches.map {
            BusinessTeamBranch(
                id: $0.id,
                name: $0.name,
                code: $0.code,
                status: $0.status
            )
        }
    }

    private func user(id: String, status: String) async throws -> BusinessTeamUser {
        let current = try await getUser(id: id)
        return BusinessTeamUser(
            id: current.id,
            email: current.email,
            displayName: current.displayName,
            phone: current.phone,
            status: status,
            scopeType: current.scopeType,
            scopeId: current.scopeId,
            branchId: current.branchId,
            roleIds: current.roleIds,
            roleNames: current.roleNames,
            highestRank: current.highestRank,
            isOrganizationSuperAdmin: current.isOrganizationSuperAdmin,
            activeSessionCount: status == "BLOCKED" ? 0 : current.activeSessionCount,
            createdAt: current.createdAt,
            updatedAt: Date()
        )
    }

    private func role(id: String) throws -> BusinessTeamRole {
        guard let role = roles.first(where: { $0.id == id }) else {
            throw PreviewBusinessTeamRepositoryError.notFound
        }
        return role
    }

    private func role(id: String, status: String) throws -> BusinessTeamRole {
        let current = try role(id: id)
        return BusinessTeamRole(
            id: current.id,
            code: current.code,
            organizationId: current.organizationId,
            scope: current.scope,
            type: current.type,
            name: current.name,
            description: current.description,
            scopeType: current.scopeType,
            rank: current.rank,
            permissionKeys: current.permissionKeys,
            systemRole: current.systemRole,
            critical: current.critical,
            editable: current.editable,
            status: status,
            schemaVersion: current.schemaVersion + 1
        )
    }
}

enum PreviewBusinessTeamRepositoryError: LocalizedError, Sendable {
    case notFound

    var errorDescription: String? {
        "No se encontró el recurso de equipo en preview."
    }
}
