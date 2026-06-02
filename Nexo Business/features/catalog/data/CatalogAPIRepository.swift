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
    private let revisionRegistry: BusinessRevisionRegistry

    public init(
        apiClient: APIClient,
        revisionRegistry: BusinessRevisionRegistry = .shared
    ) {
        self.apiClient = apiClient
        self.revisionRegistry = revisionRegistry
    }

    public func search(
        organizationId: String,
        branchId: String,
        activityId: String,
        catalogRevision: String,
        query: String,
        limit: Int = 20
    ) async throws -> CatalogSearchResponse {
        let response: CatalogSearchResponse = try await apiClient.send(
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
                headers: catalogHeaders(
                    organizationId: organizationId,
                    branchId: branchId,
                    activityId: activityId,
                    catalogRevision: catalogRevision
                )
            )
        )

        await revisionRegistry.observeCatalogRevision(
            organizationId: organizationId,
            branchId: branchId,
            activityId: activityId,
            catalogRevision: response.catalogRevision
        )

        return response
    }

    private func catalogHeaders(
        organizationId: String,
        branchId: String,
        activityId: String,
        catalogRevision: String
    ) -> [String: String] {
        var headers: [String: String] = [
            BusinessHeaders.organizationId: organizationId,
            BusinessHeaders.branchId: branchId,
            BusinessHeaders.activityId: activityId
        ]

        let normalizedRevision = catalogRevision.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedRevision.isEmpty {
            headers[BusinessHeaders.catalogRevision] = normalizedRevision
        }

        return headers
    }
}
