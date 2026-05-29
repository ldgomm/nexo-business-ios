//
//  InventoryRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public protocol InventoryRepository: Sendable {
    func listItems(
        organizationId: String,
        branchId: String,
        activityId: String,
        catalogRevision: String,
        query: String,
        stockStatus: InventoryItemStockStatus,
        limit: Int
    ) async throws -> InventoryItemsResponse

    func listMovements(
        organizationId: String,
        inventoryItemId: String,
        limit: Int
    ) async throws -> InventoryMovementsResponse

    func adjust(
        organizationId: String,
        inventoryItemId: String,
        catalogRevision: String,
        idempotencyKey: IdempotencyKey,
        request: InventoryAdjustmentRequest
    ) async throws -> InventoryAdjustmentResponse
}
