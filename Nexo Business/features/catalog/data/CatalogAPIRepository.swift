//
//  CatalogAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public enum BusinessCatalogRoutes {
    public static let items = "/api/v1/business/catalog/items"
}

public final class CatalogAPIRepository: CatalogRepository, @unchecked Sendable {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func search(
        organizationId: String,
        branchId: String,
        activityId: String,
        catalogRevision: String,
        query: String,
        limit: Int = 20
    ) async throws -> CatalogSearchResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessCatalogRoutes.items,
                queryItems: [
                    URLQueryItem(name: "branchId", value: branchId),
                    URLQueryItem(name: "activityId", value: activityId),
                    URLQueryItem(name: "q", value: query),
                    URLQueryItem(name: "limit", value: String(limit)),
                    URLQueryItem(name: "status", value: "active")
                ],
                headers: [
                    BusinessHeaders.organizationId: organizationId,
                    BusinessHeaders.catalogRevision: catalogRevision
                ]
            )
        )
    }
}
