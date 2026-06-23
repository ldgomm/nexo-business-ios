//
//  InventoryAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum BusinessInventoryRoutes {
    static let stock = "/api/v1/business/inventory/stock"
    static let adjustments = "/api/v1/business/inventory/adjustments"

    static func stockItem(itemId: String) -> String {
        "/api/v1/business/inventory/stock/\(itemId)"
    }

    static func movements(itemId: String) -> String {
        "/api/v1/business/inventory/stock/\(itemId)/movements"
    }

    static func inventorySettings(productId: String) -> String {
        "/api/v1/business/products/\(productId)/inventory-settings"
    }
}

final class InventoryAPIRepository: InventoryRepository, @unchecked Sendable {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func listItems(
        organizationId: String,
        branchId: String,
        activityId: String,
        catalogRevision: String,
        query: String,
        stockStatus: InventoryItemStockStatus,
        limit: Int = 50
    ) async throws -> InventoryItemsResponse {
        var queryItems = [
            URLQueryItem(name: "branchId", value: branchId),
            URLQueryItem(name: "activityId", value: activityId),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: trimmedQuery))
        }

        if let stockStatus = stockStatus.queryValue {
            queryItems.append(URLQueryItem(name: "stockStatus", value: stockStatus))
        }

        return try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessInventoryRoutes.stock,
                queryItems: queryItems,
                headers: [
                    BusinessHeaders.organizationId: organizationId,
                    BusinessHeaders.catalogRevision: catalogRevision
                ]
            )
        )
    }

    func listMovements(
        organizationId: String,
        inventoryItemId: String,
        limit: Int = 30
    ) async throws -> InventoryMovementsResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessInventoryRoutes.movements(itemId: inventoryItemId),
                queryItems: [URLQueryItem(name: "limit", value: String(limit))],
                headers: [
                    BusinessHeaders.organizationId: organizationId
                ]
            )
        )
    }

    func stockItem(
        organizationId: String,
        itemId: String,
        catalogRevision: String
    ) async throws -> InventoryStockItemResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessInventoryRoutes.stockItem(itemId: itemId),
                headers: [
                    BusinessHeaders.organizationId: organizationId,
                    BusinessHeaders.catalogRevision: catalogRevision
                ]
            )
        )
    }

    func adjust(
        organizationId: String,
        inventoryItemId: String,
        catalogRevision: String,
        idempotencyKey: IdempotencyKey,
        request body: InventoryAdjustmentRequest
    ) async throws -> InventoryAdjustmentResponse {
        try await apiClient.send(
            try APIRequest<InventoryAdjustmentResponse>.json(
                method: .post,
                path: BusinessInventoryRoutes.adjustments,
                body: body.withItemId(inventoryItemId),
                headers: [
                    BusinessHeaders.organizationId: organizationId,
                    BusinessHeaders.catalogRevision: catalogRevision,
                    BusinessHeaders.idempotencyKey: idempotencyKey.rawValue
                ]
            )
        )
    }
}
