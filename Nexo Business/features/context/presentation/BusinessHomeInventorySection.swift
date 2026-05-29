//
//  BusinessHomeInventorySection.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

public struct BusinessHomeInventorySection: View {
    private let organizationId: String
    private let branchId: String
    private let activityId: String
    private let catalogRevision: String
    private let effectivePermissions: Set<String>
    private let inventoryRepository: InventoryRepository

    public init(
        organizationId: String,
        branchId: String,
        activityId: String,
        catalogRevision: String,
        effectivePermissions: Set<String>,
        inventoryRepository: InventoryRepository
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.activityId = activityId
        self.catalogRevision = catalogRevision
        self.effectivePermissions = effectivePermissions
        self.inventoryRepository = inventoryRepository
    }

    public var body: some View {
        if allowsInventory {
            NavigationLink("Inventario") {
                InventoryDashboardView(
                    viewModel: InventoryDashboardViewModel(
                        organizationId: organizationId,
                        branchId: branchId,
                        activityId: activityId,
                        catalogRevision: catalogRevision,
                        effectivePermissions: effectivePermissions,
                        inventoryRepository: inventoryRepository
                    )
                )
            }
        } else {
            Label("Inventario no habilitado para este usuario", systemImage: "lock")
                .foregroundStyle(.secondary)
        }
    }

    private var allowsInventory: Bool {
        effectivePermissions.contains("business.inventory.view") ||
        effectivePermissions.contains("inventory.view") ||
        effectivePermissions.contains("business.inventory.adjust") ||
        effectivePermissions.contains("inventory.adjust")
    }
}
