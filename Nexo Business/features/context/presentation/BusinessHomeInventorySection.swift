import SwiftUI

struct BusinessHomeInventorySection: View {
    private let organizationId: String
    private let branchId: String
    private let activityId: String
    private let catalogRevision: String
    private let effectivePermissions: Set<String>
    private let inventoryRepository: InventoryRepository

    init(
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

    var body: some View {
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
        PermissionGate(effectivePermissions: effectivePermissions).allowsAny([
            "business.inventory.view",
            "inventory.view",
            "business.inventory.adjust",
            "inventory.adjust"
        ])
    }
}
