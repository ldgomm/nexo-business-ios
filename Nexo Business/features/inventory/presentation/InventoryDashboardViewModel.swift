//
//  InventoryDashboardViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class InventoryDashboardViewModel {
    private(set) var state: AsyncViewState<[InventoryItem]> = .idle
    private(set) var items: [InventoryItem] = []
    private(set) var isLoading = false
    var searchQuery = ""
    var stockStatus: InventoryItemStockStatus = .all
    var errorMessage: String?
    var infoMessage: String?
    var lowStockCount: Int?
    var outOfStockCount: Int?
    var totalCount: Int?

    let organizationId: String
    let branchId: String
    let activityId: String
    private(set) var catalogRevision: String
    let effectivePermissions: Set<String>

    private let repository: InventoryRepository

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
        self.repository = inventoryRepository
    }

    var canView: Bool {
        hasPermission([
            "business.inventory.view",
            "inventory.view",
            "business.inventory.adjust",
            "inventory.adjust"
        ])
    }

    var canAdjust: Bool {
        hasPermission([
            "business.inventory.adjust",
            "inventory.adjust"
        ])
    }

    func load() async {
        guard canView else {
            errorMessage = "No tienes permiso para consultar inventario."
            state = .failed(errorMessage ?? "")
            return
        }

        guard validateContext() else { return }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        infoMessage = nil
        state = .loading

        defer {
            isLoading = false
        }

        do {
            let response = try await repository.listItems(
                organizationId: organizationId,
                branchId: branchId,
                activityId: activityId,
                catalogRevision: catalogRevision,
                query: searchQuery,
                stockStatus: stockStatus,
                limit: 50
            )

            items = response.items
            totalCount = response.totalCount ?? response.items.count
            lowStockCount = response.lowStockCount
            outOfStockCount = response.outOfStockCount

            if let updatedRevision = response.catalogRevision, !updatedRevision.isEmpty {
                catalogRevision = updatedRevision
            }

            state = .loaded(response.items)
            infoMessage = response.items.isEmpty ? "No hay productos que coincidan con el filtro." : nil
        } catch let error as APIError {
            handle(apiError: error)
            state = .failed(error.userMessage)
        } catch {
            errorMessage = error.localizedDescription
            state = .failed(error.localizedDescription)
        }
    }

    func refresh() async {
        await load()
    }

    func makeDetailViewModel(for item: InventoryItem) -> InventoryItemDetailViewModel {
        InventoryItemDetailViewModel(
            organizationId: organizationId,
            catalogRevision: catalogRevision,
            item: item,
            effectivePermissions: effectivePermissions,
            inventoryRepository: repository
        )
    }

    func updateItem(_ item: InventoryItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            state = .loaded(items)
        }
    }

    private func validateContext() -> Bool {
        if organizationId.isEmpty || branchId.isEmpty || activityId.isEmpty {
            errorMessage = "Falta organización, sucursal o actividad operativa. Actualiza el contexto."
            state = .failed(errorMessage ?? "")
            return false
        }

        if catalogRevision.isEmpty {
            errorMessage = "Falta la revisión de catálogo. Actualiza el contexto."
            state = .failed(errorMessage ?? "")
            return false
        }

        return true
    }

    private func handle(apiError: APIError) {
        errorMessage = apiError.userMessage

        if apiError.statusCode == 409 || apiError.statusCode == 428 {
            infoMessage = "Actualiza el contexto del negocio antes de continuar."
        }
    }

    private func hasPermission(_ candidates: [String]) -> Bool {
        candidates.contains { effectivePermissions.contains($0) }
    }
}
