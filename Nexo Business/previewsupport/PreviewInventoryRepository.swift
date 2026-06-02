//
//  PreviewInventoryRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

final class PreviewInventoryRepository: InventoryRepository, @unchecked Sendable {
    init() {}

    func listItems(
        organizationId: String,
        branchId: String,
        activityId: String,
        catalogRevision: String,
        query: String,
        stockStatus: InventoryItemStockStatus,
        limit: Int
    ) async throws -> InventoryItemsResponse {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        var filtered = PreviewInventoryData.items

        if !normalizedQuery.isEmpty {
            filtered = filtered.filter { item in
                item.name.lowercased().contains(normalizedQuery) ||
                (item.sku?.lowercased().contains(normalizedQuery) ?? false) ||
                item.catalogItemId.lowercased().contains(normalizedQuery)
            }
        }

        if let status = stockStatus.queryValue {
            if status == "active" {
                filtered = filtered.filter { $0.status == "active" }
            } else {
                filtered = filtered.filter { $0.stockStatus == status }
            }
        }

        return InventoryItemsResponse(
            items: Array(filtered.prefix(limit)),
            catalogRevision: catalogRevision,
            totalCount: filtered.count,
            lowStockCount: PreviewInventoryData.items.filter { $0.stockStatus == "low_stock" }.count,
            outOfStockCount: PreviewInventoryData.items.filter { $0.stockStatus == "out_of_stock" }.count
        )
    }

    func listMovements(
        organizationId: String,
        inventoryItemId: String,
        limit: Int
    ) async throws -> InventoryMovementsResponse {
        InventoryMovementsResponse(
            movements: Array(
                PreviewInventoryData.movements
                    .filter { $0.inventoryItemId == inventoryItemId }
                    .prefix(limit)
            )
        )
    }

    func adjust(
        organizationId: String,
        inventoryItemId: String,
        catalogRevision: String,
        idempotencyKey: IdempotencyKey,
        request: InventoryAdjustmentRequest
    ) async throws -> InventoryAdjustmentResponse {
        let current = PreviewInventoryData.items.first { $0.id == inventoryItemId } ?? PreviewInventoryData.items[0]
        let updated = InventoryItem(
            id: current.id,
            catalogItemId: current.catalogItemId,
            name: current.name,
            sku: current.sku,
            barcode: current.barcode,
            status: current.status,
            stockStatus: "active",
            trackStock: current.trackStock,
            available: InventoryQuantity(
                quantity: request.quantity,
                unitCode: current.available.unitCode,
                unitName: current.available.unitName
            ),
            reserved: current.reserved,
            lowStockThreshold: current.lowStockThreshold,
            price: current.price,
            updatedAt: Date()
        )

        let movement = InventoryMovement(
            id: "mov_adjust_preview",
            inventoryItemId: inventoryItemId,
            type: request.type.rawValue,
            quantity: InventoryQuantity(
                quantity: request.quantity,
                unitCode: current.available.unitCode,
                unitName: current.available.unitName
            ),
            previousQuantity: current.available,
            newQuantity: updated.available,
            reason: request.reason,
            createdAt: Date()
        )

        return InventoryAdjustmentResponse(
            item: updated,
            movement: movement,
            catalogRevision: catalogRevision,
            idempotencyReplayed: false
        )
    }
}
