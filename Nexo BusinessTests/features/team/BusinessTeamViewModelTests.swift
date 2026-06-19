//
//  BusinessTeamViewModelTests.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import XCTest
@testable import Nexo_Business

@MainActor
final class BusinessTeamViewModelTests: XCTestCase {
    func testLoadPublishesUsersRolesTemplatesAndPermissions() async {
        let repository = BusinessTeamRepositorySpy()
        let viewModel = BusinessTeamViewModel(repository: repository)

        await viewModel.load()

        XCTAssertEqual(viewModel.users.map(\.id), ["usr_cashier"])
        XCTAssertEqual(viewModel.roles.map(\.id), ["role_cashier", "role_discount"])
        XCTAssertEqual(viewModel.roleTemplates.map(\.templateCode), ["core.cashier", "core.discount_manager"])
        XCTAssertEqual(viewModel.capabilityGroups.map(\.code), ["SALES", "SALES_DISCOUNTS"])
        XCTAssertEqual(viewModel.permissions.map(\.code), ["sales.create", "sales.apply_discount"])
        XCTAssertEqual(viewModel.selectedRoleIds, ["role_discount"])
        XCTAssertEqual(viewModel.state, .loaded)
    }

    func testUserHasDiscountAccessFromRole() async {
        let repository = BusinessTeamRepositorySpy()
        let viewModel = BusinessTeamViewModel(repository: repository)
        await viewModel.load()
        let user = BusinessTeamUser.fixture(roleIds: ["role_discount"], roleNames: ["Encargado de descuentos"])

        XCTAssertTrue(viewModel.userHasDiscountAccess(user))
        XCTAssertEqual(viewModel.discountAccessDescription(for: user), "Puede aplicar descuentos en ventas.")
    }

    func testUpdateUserRolesRequiresReason() async {
        let repository = BusinessTeamRepositorySpy()
        let viewModel = BusinessTeamViewModel(repository: repository)
        await viewModel.load()
        let user = BusinessTeamUser.fixture()

        let success = await viewModel.updateUserRoles(
            user: user,
            roleIds: ["role_cashier"],
            reason: "   ",
            revokeSessions: false
        )

        XCTAssertFalse(success)
        XCTAssertEqual(viewModel.errorMessage, "Ingresa un motivo para cambiar los permisos.")
        XCTAssertTrue(repository.updatedUsers.isEmpty)
    }

    func testUpdateUserRolesUpdatesRolesAndRevokesSessions() async {
        let repository = BusinessTeamRepositorySpy()
        let viewModel = BusinessTeamViewModel(repository: repository)
        await viewModel.load()
        let user = BusinessTeamUser.fixture(roleIds: ["role_cashier"])

        let success = await viewModel.updateUserRoles(
            user: user,
            roleIds: ["role_cashier", "role_discount"],
            reason: "Autorizar descuentos",
            revokeSessions: true
        )

        XCTAssertTrue(success)
        XCTAssertEqual(repository.updatedUsers.first?.id, "usr_cashier")
        XCTAssertEqual(repository.updatedUsers.first?.input.roleIds, ["role_cashier", "role_discount"])
        XCTAssertEqual(repository.revokedSessions.first?.userId, "usr_cashier")
        XCTAssertEqual(repository.revokedSessions.first?.reason, "Autorizar descuentos · Revocar sesiones para aplicar permisos actualizados")
        XCTAssertEqual(viewModel.infoMessage, "Permisos de descuento otorgados y sesiones revocadas.")
    }

    func testReadableCapabilitiesUsesBackendCapabilityGroups() async {
        let repository = BusinessTeamRepositorySpy()
        let viewModel = BusinessTeamViewModel(repository: repository)
        await viewModel.load()

        XCTAssertEqual(viewModel.readableCapabilities(for: ["sales.create"]), ["Ventas"])
        XCTAssertEqual(viewModel.readableCapabilities(for: ["sales.apply_discount"]), ["Descuentos"])
        XCTAssertEqual(viewModel.readableCapabilities(for: ["unknown.permission"]), ["Permisos operativos básicos"])
    }

    func testReadableCapabilitiesPrefersTemplateCapabilityGroups() async {
        let repository = BusinessTeamRepositorySpy()
        let viewModel = BusinessTeamViewModel(repository: repository)
        await viewModel.load()
        let template = BusinessRoleTemplate.fixture(
            templateCode: "core.discount_manager",
            name: "Encargado de descuentos",
            capabilityGroups: [
                BusinessHumanCapabilityGroup(
                    code: "SALES_DISCOUNTS",
                    title: "Descuentos",
                    permissionKeys: ["sales.apply_discount"],
                    rank: 160
                )
            ]
        )

        XCTAssertEqual(viewModel.readableCapabilities(for: template), ["Descuentos"])
    }

    func testTeamActionsAreReadOnlyWithoutMutationPermissions() async {
        let repository = BusinessTeamRepositorySpy()
        let viewModel = BusinessTeamViewModel(
            repository: repository,
            effectivePermissions: ["credentials.users.view", "credentials.roles.view"]
        )
        await viewModel.load()

        XCTAssertFalse(viewModel.canCreateTeamUsers)
        XCTAssertFalse(viewModel.canAssignRoles)
        XCTAssertFalse(viewModel.canCreateRolesFromTemplates)
        XCTAssertEqual(viewModel.readOnlyTeamReason, "Tu rol permite revisar el equipo, pero no hacer cambios.")

        await viewModel.createRoleFromTemplate(.fixture(templateCode: "core.cashier", name: "Cajero"), reason: "Crear")

        XCTAssertEqual(viewModel.errorMessage, "Tu rol no permite crear roles desde plantillas.")
        XCTAssertTrue(repository.createdTemplateInputs.isEmpty)
    }

    func testCapabilitySummariesExposeHumanBulletsAndTechnicalRows() async {
        let repository = BusinessTeamRepositorySpy()
        let viewModel = BusinessTeamViewModel(repository: repository)
        await viewModel.load()

        let summaries = viewModel.capabilityGroupSummaries(for: BusinessTeamRole.cashier)
        XCTAssertEqual(summaries.map(\.title), ["Ventas"])
        XCTAssertEqual(summaries.first?.humanBullets, ["Puede crear ventas"])

        let rows = viewModel.technicalPermissionRows(for: ["sales.create", "unknown.permission"])
        XCTAssertEqual(rows.map(\.code), ["sales.create", "unknown.permission"])
        XCTAssertEqual(rows.first?.label, "Crear ventas")
        XCTAssertEqual(rows.last?.category, "Sin clasificar")
    }

    func testCreateRoleFromTemplateAddsCreatedRole() async {
        let repository = BusinessTeamRepositorySpy()
        let viewModel = BusinessTeamViewModel(repository: repository)
        await viewModel.load()
        let template = BusinessRoleTemplate.fixture(templateCode: "core.discount_manager", name: "Encargado de descuentos")

        await viewModel.createRoleFromTemplate(template, reason: "Crear rol de descuentos")

        XCTAssertEqual(repository.createdTemplateInputs.first?.templateCode, "core.discount_manager")
        XCTAssertEqual(repository.createdTemplateInputs.first?.reason, "Crear rol de descuentos")
        XCTAssertTrue(viewModel.roles.contains { $0.id == "role_from_template" })
    }
}

private final class BusinessTeamRepositorySpy: BusinessTeamRepository, @unchecked Sendable {
    var users: [BusinessTeamUser] = [.fixture()]
    var roles: [BusinessTeamRole] = [.cashier, .discountManager]
    var roleTemplates: [BusinessRoleTemplate] = [
        .fixture(templateCode: "core.cashier", name: "Cajero"),
        .fixture(templateCode: "core.discount_manager", name: "Encargado de descuentos")
    ]
    var capabilityGroups: [BusinessHumanCapabilityGroup] = [
        BusinessHumanCapabilityGroup(
            code: "SALES",
            title: "Ventas",
            description: "Permite vender desde el negocio.",
            humanBullets: ["Puede crear ventas"],
            permissionKeys: ["sales.create"],
            rank: 100
        ),
        BusinessHumanCapabilityGroup(
            code: "SALES_DISCOUNTS",
            title: "Descuentos",
            permissionKeys: ["sales.apply_discount"],
            sensitive: true,
            rank: 160
        )
    ]
    var permissions: [BusinessTeamPermission] = [
        BusinessTeamPermission(code: "sales.create", name: "Crear ventas", description: "", category: "SALES", humanLabel: "Crear ventas"),
        BusinessTeamPermission(code: "sales.apply_discount", name: "Aplicar descuentos", description: "", category: "SALES")
    ]
    var branches: [BusinessTeamBranch] = [BusinessTeamBranch(id: "br_1", name: "Matriz", code: "001", status: "ACTIVE")]
    var updatedUsers: [(id: String, input: UpdateBusinessTeamUserInput)] = []
    var revokedSessions: [(userId: String, reason: String)] = []
    var createdTemplateInputs: [CreateBusinessRoleFromTemplateInput] = []

    func listUsers(query: String?, status: String?, branchId: String?, limit: Int) async throws -> [BusinessTeamUser] { users }
    func getUser(id: String) async throws -> BusinessTeamUser { users.first { $0.id == id } ?? .fixture() }
    func createTemporaryUser(_ input: CreateBusinessTeamUserInput) async throws -> BusinessTeamTemporaryUserResponse {
        BusinessTeamTemporaryUserResponse(
            user: .fixture(id: "usr_new", email: input.email, displayName: input.displayName, roleIds: input.roleIds),
            credentialId: "cred_new",
            membershipId: "mem_new",
            temporaryPassword: "Temp1234!",
            mustChangePassword: true,
            createdAt: Date()
        )
    }
    func updateUser(id: String, input: UpdateBusinessTeamUserInput) async throws -> BusinessTeamUser {
        updatedUsers.append((id, input))
        let updated = BusinessTeamUser.fixture(roleIds: input.roleIds ?? [])
        users = users.map { $0.id == id ? updated : $0 }
        return updated
    }
    func blockUser(id: String, reason: String) async throws -> BusinessTeamUser { .fixture(status: "BLOCKED") }
    func unblockUser(id: String, reason: String) async throws -> BusinessTeamUser { .fixture(status: "ACTIVE") }
    func resetPassword(userId: String, temporaryPassword: String?, revokeSessions: Bool, reason: String) async throws -> BusinessTeamTemporaryPasswordResult {
        BusinessTeamTemporaryPasswordResult(userId: userId, temporaryPassword: "Temp1234!", mustChangePassword: true, revokedSessions: 1, changedAt: Date())
    }
    func revokeSessions(userId: String, reason: String) async throws -> BusinessTeamSessionRevocationResult {
        revokedSessions.append((userId, reason))
        return BusinessTeamSessionRevocationResult(userId: userId, revokedSessions: 1, revokedRefreshTokens: 1, revokedAt: Date(), reason: reason)
    }
    func listRoles(includeSystemTemplates: Bool) async throws -> [BusinessTeamRole] { roles }
    func createRole(_ input: CreateBusinessTeamRoleInput) async throws -> BusinessTeamRole { .discountManager }
    func createRoleFromTemplate(_ input: CreateBusinessRoleFromTemplateInput) async throws -> BusinessTeamRole {
        createdTemplateInputs.append(input)
        let role = BusinessTeamRole(
            id: "role_from_template",
            code: input.code ?? "from_template",
            name: input.name ?? "Rol desde plantilla",
            description: input.description ?? "Creado desde plantilla",
            scopeType: "ORGANIZATION",
            rank: 300,
            permissionKeys: ["sales.apply_discount"],
            systemRole: false,
            critical: false,
            editable: true,
            status: "ACTIVE",
            schemaVersion: 1
        )
        roles.append(role)
        return role
    }
    func updateRole(id: String, input: UpdateBusinessTeamRoleInput) async throws -> BusinessTeamRole { .discountManager }
    func activateRole(id: String, reason: String) async throws -> BusinessTeamRole { .discountManager }
    func deactivateRole(id: String, reason: String) async throws -> BusinessTeamRole { .discountManager }
    func listRoleTemplates(vertical: String?) async throws -> [BusinessRoleTemplate] { roleTemplates }
    func listCapabilityGroups() async throws -> [BusinessHumanCapabilityGroup] { capabilityGroups }
    func listPermissions(includeReserved: Bool) async throws -> [BusinessTeamPermission] { permissions }
    func listAssignablePermissions() async throws -> [BusinessTeamPermission] { permissions }
    func listBranches() async throws -> [BusinessTeamBranch] { branches }
}

private extension BusinessTeamUser {
    static func fixture(
        id: String = "usr_cashier",
        email: String = "cashier@nexo.test",
        displayName: String = "Cajero",
        status: String = "ACTIVE",
        roleIds: Set<String> = ["role_cashier"],
        roleNames: [String] = ["Cajero"]
    ) -> BusinessTeamUser {
        BusinessTeamUser(
            id: id,
            email: email,
            displayName: displayName,
            status: status,
            scopeType: "ORGANIZATION",
            scopeId: "org_1",
            roleIds: roleIds,
            roleNames: roleNames,
            highestRank: 300,
            isOrganizationSuperAdmin: false,
            activeSessionCount: 1,
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1)
        )
    }
}

private extension BusinessTeamRole {
    static let cashier = BusinessTeamRole(
        id: "role_cashier",
        code: "cajero",
        name: "Cajero",
        description: "Puede vender y cobrar",
        scopeType: "ORGANIZATION",
        rank: 300,
        permissionKeys: ["sales.create", "payments.collect"],
        systemRole: false,
        critical: false,
        editable: true,
        status: "ACTIVE",
        schemaVersion: 1
    )

    static let discountManager = BusinessTeamRole(
        id: "role_discount",
        code: "encargado_descuentos",
        name: "Encargado de descuentos",
        description: "Puede aplicar descuentos",
        scopeType: "ORGANIZATION",
        rank: 320,
        permissionKeys: ["sales.apply_discount"],
        systemRole: false,
        critical: false,
        editable: true,
        status: "ACTIVE",
        schemaVersion: 1
    )
}

private extension BusinessRoleTemplate {
    static func fixture(
        templateCode: String = "core.cashier",
        name: String = "Cajero",
        capabilityGroups: [BusinessHumanCapabilityGroup] = []
    ) -> BusinessRoleTemplate {
        BusinessRoleTemplate(
            templateCode: templateCode,
            vertical: "CORE",
            roleCode: templateCode.components(separatedBy: ".").last ?? "role",
            name: name,
            description: "Plantilla de prueba",
            permissionKeys: ["sales.create"],
            requiredModules: ["core.sales"],
            assignableByBusiness: true,
            editableByBusiness: true,
            critical: false,
            rank: 300,
            capabilityGroups: capabilityGroups
        )
    }
}
