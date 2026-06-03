import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class BusinessTeamViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case failed(String)
    }

    private let repository: BusinessTeamRepository

    var state: State = .idle
    var users: [BusinessTeamUser] = []
    var roles: [BusinessTeamRole] = []
    var roleTemplates: [BusinessRoleTemplate] = []
    var permissions: [BusinessTeamPermission] = []
    var branches: [BusinessTeamBranch] = []
    var query: String = ""
    var createEmail = ""
    var createDisplayName = ""
    var createPhone = ""
    var createReason = "Crear usuario desde Business"
    var selectedRoleIds: Set<String> = []
    var selectedTemplateVertical: String? = nil
    var actionReason = ""
    var lastTemporaryPassword: String?
    var errorMessage: String?
    var infoMessage: String?
    var isMutating = false

    init(repository: BusinessTeamRepository) {
        self.repository = repository
    }

    var activeRoles: [BusinessTeamRole] {
        roles
            .filter(\.canBeAssignedFromBusiness)
            .sorted { lhs, rhs in
                if lhs.rank != rhs.rank { return lhs.rank > rhs.rank }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    var assignablePermissions: [BusinessTeamPermission] {
        permissions
            .filter { $0.assignable }
            .sorted { $0.humanLabel.localizedCaseInsensitiveCompare($1.humanLabel) == .orderedAscending }
    }

    var discountRoles: [BusinessTeamRole] {
        activeRoles.filter { roleGrantsDiscounts($0) }
    }

    var availableTemplates: [BusinessRoleTemplate] {
        roleTemplates.sorted { lhs, rhs in
            if lhs.vertical != rhs.vertical { return lhs.vertical < rhs.vertical }
            if lhs.rank != rhs.rank { return lhs.rank > rhs.rank }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var canCreateUser: Bool {
        createEmail.contains("@") &&
        !createDisplayName.trimmed.isEmpty &&
        !selectedRoleIds.isEmpty &&
        !createReason.trimmed.isEmpty
    }

    func load() async {
        state = .loading
        errorMessage = nil

        do {
            async let loadedUsers = repository.listUsers(
                query: query.nilIfBlank,
                status: nil,
                branchId: nil,
                limit: 100
            )

            async let loadedRoles = repository.listRoles(includeSystemTemplates: false)
            async let loadedTemplates = repository.listRoleTemplates(vertical: selectedTemplateVertical)
            async let loadedPermissions = repository.listPermissions(includeReserved: false)
            async let loadedBranches = repository.listBranches()

            self.users = try await loadedUsers
            self.roles = try await loadedRoles
            self.roleTemplates = try await loadedTemplates
            self.permissions = try await loadedPermissions
            self.branches = try await loadedBranches

            if selectedRoleIds.isEmpty, let first = activeRoles.first {
                selectedRoleIds = [first.id]
            }

            state = self.users.isEmpty ? .empty : .loaded
        } catch let error as APIError {
            state = .failed(error.userMessage)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func refreshUser(_ userId: String) async -> BusinessTeamUser? {
        do {
            let user = try await repository.getUser(id: userId)
            upsert(user)
            return user
        } catch {
            return user(withId: userId)
        }
    }

    func user(withId id: String) -> BusinessTeamUser? {
        users.first { $0.id == id }
    }

    func role(withId id: String) -> BusinessTeamRole? {
        roles.first { $0.id == id }
    }

    func roles(for user: BusinessTeamUser) -> [BusinessTeamRole] {
        roles
            .filter { user.roleIds.contains($0.id) }
            .sorted { lhs, rhs in
                if lhs.rank != rhs.rank { return lhs.rank > rhs.rank }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    func branchName(for user: BusinessTeamUser) -> String? {
        guard let branchId = user.branchId?.trimmed.nilIfBlank else { return nil }
        return branches.first { $0.id == branchId }?.name ?? branchId
    }

    func roleGrantsDiscounts(_ role: BusinessTeamRole) -> Bool {
        Self.discountPermissionKeys.contains { role.permissionKeys.contains($0) }
    }

    func userHasDiscountAccess(_ user: BusinessTeamUser) -> Bool {
        let roleBased = roles(for: user).contains { roleGrantsDiscounts($0) }
        let direct = Self.discountPermissionKeys.contains { user.effectivePermissions?.contains($0) == true }
        return roleBased || direct
    }

    func discountAccessDescription(for user: BusinessTeamUser) -> String {
        userHasDiscountAccess(user)
        ? "Puede aplicar descuentos en ventas."
        : "No puede aplicar descuentos."
    }

    func roleDescription(for role: BusinessTeamRole) -> String {
        let permissionCount = role.permissionKeys.count
        let permissionText = permissionCount == 1 ? "1 permiso" : "\(permissionCount) permisos"

        if roleGrantsDiscounts(role) { return "\(permissionText) · incluye descuentos" }
        if role.critical { return "\(permissionText) · rol sensible" }
        if role.systemRole { return "\(permissionText) · rol base" }
        return permissionText
    }

    func readableCapabilities(for permissionKeys: Set<String>) -> [String] {
        var capabilities: [String] = []
        if permissionKeys.contains(where: { $0.contains("sales.create") || $0 == "sales.create" }) { capabilities.append("Puede vender") }
        if permissionKeys.contains(where: { $0.contains("payments.collect") || $0 == "payments.collect" }) { capabilities.append("Puede cobrar") }
        if permissionKeys.contains(where: { $0.contains("cash") }) { capabilities.append("Puede operar caja") }
        if Self.discountPermissionKeys.contains(where: permissionKeys.contains) { capabilities.append("Puede aplicar descuentos") }
        if permissionKeys.contains(where: { $0.contains("reports") }) { capabilities.append("Puede ver reportes") }
        if permissionKeys.contains(where: { $0.contains("credentials.users") || $0.contains("roles") || $0.contains("team") }) { capabilities.append("Puede administrar equipo") }
        if permissionKeys.contains(where: { $0.contains("catalog") || $0.contains("inventory") }) { capabilities.append("Puede ver productos/inventario") }
        return capabilities.isEmpty ? ["Permisos operativos básicos"] : Array(Set(capabilities)).sorted()
    }

    func createUser() async {
        guard canCreateUser else {
            errorMessage = "Completa correo, nombre, rol y motivo."
            return
        }

        await mutate(successMessage: "Usuario creado correctamente.") {
            let created = try await repository.createTemporaryUser(
                CreateBusinessTeamUserInput(
                    email: createEmail.trimmed,
                    displayName: createDisplayName.trimmed,
                    roleIds: selectedRoleIds,
                    temporaryPassword: nil,
                    phone: createPhone.trimmed.nilIfBlank,
                    reason: createReason.trimmed
                )
            )

            lastTemporaryPassword = created.temporaryPassword
            createEmail = ""
            createDisplayName = ""
            createPhone = ""
        }
    }

    @discardableResult
    func updateUserRoles(
        user: BusinessTeamUser,
        roleIds: Set<String>,
        reason: String,
        revokeSessions: Bool
    ) async -> Bool {
        let normalizedReason = reason.trimmed

        guard !roleIds.isEmpty else {
            errorMessage = "Selecciona al menos un rol para el usuario."
            return false
        }

        guard !normalizedReason.isEmpty else {
            errorMessage = "Ingresa un motivo para cambiar los permisos."
            return false
        }

        return await mutateReturning(successMessage: successTextForRoleChange(user: user, roleIds: roleIds, revokedSessions: revokeSessions)) {
            let updatedUser = try await repository.updateUser(
                id: user.id,
                input: UpdateBusinessTeamUserInput(
                    roleIds: roleIds,
                    reason: normalizedReason,
                    scopeType: user.scopeType,
                    scopeId: user.scopeId
                )
            )

            upsert(updatedUser)

            if revokeSessions {
                _ = try await repository.revokeSessions(
                    userId: user.id,
                    reason: "\(normalizedReason) · Revocar sesiones para aplicar permisos actualizados"
                )
            }
        }
    }

    func createRoleFromTemplate(_ template: BusinessRoleTemplate, reason: String) async {
        let normalizedReason = reason.trimmed.nilIfBlank ?? "Crear rol desde plantilla \(template.name)"
        await mutate(successMessage: "Rol \(template.name) creado desde plantilla.") {
            let role = try await repository.createRoleFromTemplate(
                CreateBusinessRoleFromTemplateInput(
                    templateCode: template.templateCode,
                    reason: normalizedReason
                )
            )
            roles.append(role)
        }
    }

    func block(_ user: BusinessTeamUser, reason: String) async {
        let normalizedReason = reason.trimmed.nilIfBlank ?? "Bloquear usuario desde Business"
        await mutate(successMessage: "Usuario bloqueado correctamente.") {
            let updated = try await repository.blockUser(id: user.id, reason: normalizedReason)
            upsert(updated)
        }
    }

    func unblock(_ user: BusinessTeamUser, reason: String) async {
        let normalizedReason = reason.trimmed.nilIfBlank ?? "Desbloquear usuario desde Business"
        await mutate(successMessage: "Usuario desbloqueado correctamente.") {
            let updated = try await repository.unblockUser(id: user.id, reason: normalizedReason)
            upsert(updated)
        }
    }

    func resetPassword(_ user: BusinessTeamUser, reason: String) async {
        let normalizedReason = reason.trimmed.nilIfBlank ?? "Resetear contraseña desde Business"
        await mutate(successMessage: "Contraseña temporal generada.") {
            let response = try await repository.resetPassword(
                userId: user.id,
                temporaryPassword: nil,
                revokeSessions: true,
                reason: normalizedReason
            )
            lastTemporaryPassword = response.temporaryPassword
        }
    }

    func revokeSessions(_ user: BusinessTeamUser, reason: String) async {
        let normalizedReason = reason.trimmed.nilIfBlank ?? "Revocar sesiones desde Business"
        await mutate(successMessage: "Sesiones revocadas correctamente.") {
            _ = try await repository.revokeSessions(userId: user.id, reason: normalizedReason)
        }
    }

    private func mutate(successMessage: String, _ operation: () async throws -> Void) async {
        _ = await mutateReturning(successMessage: successMessage, operation)
    }

    @discardableResult
    private func mutateReturning(successMessage: String, _ operation: () async throws -> Void) async -> Bool {
        guard !isMutating else { return false }

        isMutating = true
        errorMessage = nil
        infoMessage = nil

        defer { isMutating = false }

        do {
            try await operation()
            infoMessage = successMessage
            await load()
            return true
        } catch let error as APIError {
            errorMessage = error.userMessage
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func upsert(_ user: BusinessTeamUser) {
        if let index = users.firstIndex(where: { $0.id == user.id }) {
            users[index] = user
        } else {
            users.insert(user, at: 0)
        }
    }

    private func successTextForRoleChange(
        user: BusinessTeamUser,
        roleIds: Set<String>,
        revokedSessions: Bool
    ) -> String {
        let previous = userHasDiscountAccess(user)
        let next = roles
            .filter { roleIds.contains($0.id) }
            .contains { roleGrantsDiscounts($0) }

        if !previous && next {
            return revokedSessions ? "Permisos de descuento otorgados y sesiones revocadas." : "Permisos de descuento otorgados."
        }

        if previous && !next {
            return revokedSessions ? "Permisos de descuento retirados y sesiones revocadas." : "Permisos de descuento retirados."
        }

        return revokedSessions ? "Roles actualizados y sesiones revocadas." : "Roles actualizados correctamente."
    }

    static let discountPermissionKeys: Set<String> = [
        "sales.apply_discount",
        "sales.apply_item_discount",
        "sales.apply_selected_items_discount",
        "sales.apply_cart_discount",
        "sales.remove_discount",
        "sales.override_discount_limit",
        "business.sales.apply_discount",
        "business.sales.apply_item_discount",
        "business.sales.apply_selected_items_discount",
        "business.sales.apply_cart_discount",
        "business.sales.remove_discount",
        "business.sales.override_discount_limit"
    ]
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfBlank: String? { trimmed.isEmpty ? nil : trimmed }
}
