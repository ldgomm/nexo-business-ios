//
//  InventoryAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public enum BusinessInventoryRoutes {
    public static let items = "/api/v1/business/inventory/items"

    public static func movements(inventoryItemId: String) -> String {
        "/api/v1/business/inventory/items/\(inventoryItemId)/movements"
    }

    public static func adjustments(inventoryItemId: String) -> String {
        "/api/v1/business/inventory/items/\(inventoryItemId)/adjustments"
    }
}

public final class InventoryAPIRepository: InventoryRepository, @unchecked Sendable {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func listItems(
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
                path: BusinessInventoryRoutes.items,
                queryItems: queryItems,
                headers: [
                    BusinessHeaders.organizationId: organizationId,
                    BusinessHeaders.catalogRevision: catalogRevision
                ]
            )
        )
    }

    public func listMovements(
        organizationId: String,
        inventoryItemId: String,
        limit: Int = 30
    ) async throws -> InventoryMovementsResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessInventoryRoutes.movements(inventoryItemId: inventoryItemId),
                queryItems: [URLQueryItem(name: "limit", value: String(limit))],
                headers: [
                    BusinessHeaders.organizationId: organizationId
                ]
            )
        )
    }

    public func adjust(
        organizationId: String,
        inventoryItemId: String,
        catalogRevision: String,
        idempotencyKey: IdempotencyKey,
        request body: InventoryAdjustmentRequest
    ) async throws -> InventoryAdjustmentResponse {
        try await apiClient.send(
            try APIRequest<InventoryAdjustmentResponse>.json(
                method: .post,
                path: BusinessInventoryRoutes.adjustments(inventoryItemId: inventoryItemId),
                body: body,
                headers: [
                    BusinessHeaders.organizationId: organizationId,
                    BusinessHeaders.catalogRevision: catalogRevision,
                    BusinessHeaders.idempotencyKey: idempotencyKey.rawValue
                ]
            )
        )
    }
}
