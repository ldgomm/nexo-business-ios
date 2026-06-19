//
//  CatalogAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum BusinessCatalogRoutes {
    static let items = "/api/v1/business/catalog/items"

    static func masterTemplates(organizationId: String) -> String {
        "/organizations/\(organizationId)/catalog/master/templates"
    }

    static func copyFromMaster(organizationId: String) -> String {
        "/organizations/\(organizationId)/catalog/items/copy-from-master"
    }
}

final class CatalogAPIRepository: CatalogRepository, @unchecked Sendable {
    private let apiClient: APIClient
    private let revisionRegistry: BusinessRevisionRegistry

    init(
        apiClient: APIClient,
        revisionRegistry: BusinessRevisionRegistry = .shared
    ) {
        self.apiClient = apiClient
        self.revisionRegistry = revisionRegistry
    }

    func search(
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



    func searchSuggestions(
        organizationId: String,
        query: String,
        limit: Int = 20
    ) async throws -> CatalogSuggestionSearchResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessCatalogRoutes.masterTemplates(organizationId: organizationId),
                queryItems: [
                    URLQueryItem(name: "query", value: query),
                    URLQueryItem(name: "limit", value: String(limit))
                ],
                headers: [BusinessHeaders.organizationId: organizationId]
            )
        )
    }

    func adoptSuggestion(
        organizationId: String,
        branchId: String?,
        activityId: String,
        template: PlatformCatalogTemplateSuggestion,
        localPrice: MoneyAmount,
        taxProfileCode: String,
        reason: String
    ) async throws -> BusinessCatalogItem {
        let request = CatalogCopyFromTemplateRequest(
            templateId: template.id,
            branchId: branchId,
            activityId: activityId,
            localPrice: localPrice,
            taxProfileCode: taxProfileCode,
            reason: reason
        )

        return try await apiClient.send(
            APIRequest<BusinessCatalogItem>.json(
                method: .post,
                path: BusinessCatalogRoutes.copyFromMaster(organizationId: organizationId),
                body: request,
                headers: [BusinessHeaders.organizationId: organizationId]
            )
        )
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
