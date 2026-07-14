//
//  InventoryRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

protocol InventoryRepository: Sendable {
    func listItems(
        organizationId: String,
        branchId: String,
        activityId: String,
        catalogRevision: String,
        query: String,
        stockStatus: InventoryItemStockStatus,
        limit: Int
    ) async throws -> InventoryItemsResponse

    func listItems(
        organizationId: String,
        branchId: String,
        activityId: String,
        catalogRevision: String,
        query: String,
        stockStatus: InventoryItemStockStatus,
        cursor: String?,
        limit: Int
    ) async throws -> InventoryItemsResponse

    func listMovements(
        organizationId: String,
        branchId: String,
        catalogItemId: String,
        limit: Int
    ) async throws -> InventoryMovementsResponse

    func lookupStock(
        organizationId: String,
        branchId: String,
        itemId: String,
        catalogRevision: String
    ) async throws -> InventoryStockLookupResponse

    func adjust(
        organizationId: String,
        branchId: String,
        catalogItemId: String,
        catalogRevision: String,
        idempotencyKey: IdempotencyKey,
        request: InventoryAdjustmentRequest
    ) async throws -> InventoryAdjustmentResponse
}

extension InventoryRepository {
    func lookupStock(
        organizationId: String,
        branchId: String,
        itemId: String,
        catalogRevision: String
    ) async throws -> InventoryStockLookupResponse {
        throw InventoryRepositoryCapabilityError.stockLookupUnavailable
    }

    func listItems(
        organizationId: String,
        branchId: String,
        activityId: String,
        catalogRevision: String,
        query: String,
        stockStatus: InventoryItemStockStatus,
        cursor: String?,
        limit: Int
    ) async throws -> InventoryItemsResponse {
        try await listItems(
            organizationId: organizationId,
            branchId: branchId,
            activityId: activityId,
            catalogRevision: catalogRevision,
            query: query,
            stockStatus: stockStatus,
            limit: limit
        )
    }
}

enum InventoryRepositoryCapabilityError: LocalizedError {
    case stockLookupUnavailable

    var errorDescription: String? {
        "La consulta individual de stock no está disponible."
    }
}
