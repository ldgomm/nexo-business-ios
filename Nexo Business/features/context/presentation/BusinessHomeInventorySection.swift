//
//  BusinessHomeInventorySection.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

public struct BusinessHomeInventorySection: View {
    private let context: BusinessContextResponse
    private let inventoryRepository: InventoryRepository

    public init(
        context: BusinessContextResponse,
        inventoryRepository: InventoryRepository
    ) {
        self.context = context
        self.inventoryRepository = inventoryRepository
    }

    public var body: some View {
        let moduleGate = ModuleGate(activeModules: context.activeModules)
        let permissionGate = PermissionGate(effectivePermissions: context.effectivePermissions)
        let branchId = context.branches.first?.id ?? ""
        let activityId = context.activities.first?.id ?? ""

        if allowsInventory(moduleGate: moduleGate, permissionGate: permissionGate) {
            NavigationLink("Inventario") {
                InventoryDashboardView(
                    viewModel: InventoryDashboardViewModel(
                        organizationId: context.organization.id,
                        branchId: branchId,
                        activityId: activityId,
                        catalogRevision: context.revisions.catalogRevision,
                        effectivePermissions: context.effectivePermissions,
                        inventoryRepository: inventoryRepository
                    )
                )
            }
        } else {
            Label("Inventario no habilitado para este usuario", systemImage: "lock")
                .foregroundStyle(.secondary)
        }
    }

    private func allowsInventory(
        moduleGate: ModuleGate,
        permissionGate: PermissionGate
    ) -> Bool {
        let moduleEnabled = moduleGate.allows("core.inventory") || moduleGate.allows("inventory.basic")
        let hasPermission = permissionGate.allows("business.inventory.view") ||
            permissionGate.allows("inventory.view") ||
            permissionGate.allows("business.inventory.adjust") ||
            permissionGate.allows("inventory.adjust")

        return moduleEnabled || hasPermission
    }
}
