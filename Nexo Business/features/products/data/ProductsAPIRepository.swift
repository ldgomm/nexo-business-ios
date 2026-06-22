//
//  ProductsAPIRepository.swift
//  Nexo Business
//

import Foundation

enum BusinessProductsRoutes {
    static let products = "/api/v1/business/products"
    static let taxProfiles = "/api/v1/business/tax-profiles"

    static func product(_ productId: String) -> String {
        "/api/v1/business/products/\(productId)"
    }

    static func deactivate(_ productId: String) -> String {
        "/api/v1/business/products/\(productId)/deactivate"
    }

    static func activate(_ productId: String) -> String {
        "/api/v1/business/products/\(productId)/activate"
    }
}

final class ProductsAPIRepository: ProductsRepository, @unchecked Sendable {
    private let apiClient: APIClient
    private let revisionRegistry: BusinessRevisionRegistry

    init(apiClient: APIClient, revisionRegistry: BusinessRevisionRegistry = .shared) {
        self.apiClient = apiClient
        self.revisionRegistry = revisionRegistry
    }

    func listTaxProfiles(organizationId: String) async throws -> BusinessTaxProfilesResponse {
        let response: BusinessTaxProfilesResponse = try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessProductsRoutes.taxProfiles,
                queryItems: [URLQueryItem(name: "usage", value: "products")],
                headers: [BusinessHeaders.organizationId: organizationId]
            )
        )
        return response
    }

    func listProducts(
        organizationId: String,
        branchId: String,
        activityId: String,
        catalogRevision: String,
        query: String,
        status: String?,
        limit: Int
    ) async throws -> BusinessProductsResponse {
        let response: BusinessProductsResponse = try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessProductsRoutes.products,
                queryItems: [
                    URLQueryItem(name: "branchId", value: branchId),
                    URLQueryItem(name: "activityId", value: activityId),
                    URLQueryItem(name: "q", value: query),
                    URLQueryItem(name: "status", value: status ?? "all"),
                    URLQueryItem(name: "limit", value: String(limit))
                ],
                headers: headers(
                    organizationId: organizationId,
                    branchId: branchId,
                    activityId: activityId,
                    catalogRevision: catalogRevision
                )
            )
        )
        await observe(response.catalogRevision, organizationId: organizationId, branchId: branchId, activityId: activityId)
        return response
    }

    func createProduct(
        organizationId: String,
        branchId: String,
        activityId: String,
        request: BusinessProductUpsertRequest
    ) async throws -> BusinessProductMutationResponse {
        let response: BusinessProductMutationResponse = try await apiClient.send(
            APIRequest<BusinessProductMutationResponse>.json(
                method: .post,
                path: BusinessProductsRoutes.products,
                body: request,
                headers: headers(organizationId: organizationId, branchId: branchId, activityId: activityId, catalogRevision: "")
            )
        )
        await observe(response.catalogRevision, organizationId: organizationId, branchId: branchId, activityId: activityId)
        return response
    }

    func updateProduct(
        organizationId: String,
        branchId: String,
        activityId: String,
        productId: String,
        request: BusinessProductPatchRequest
    ) async throws -> BusinessProductMutationResponse {
        let response: BusinessProductMutationResponse = try await apiClient.send(
            APIRequest<BusinessProductMutationResponse>.json(
                method: .patch,
                path: BusinessProductsRoutes.product(productId),
                body: request,
                headers: headers(organizationId: organizationId, branchId: branchId, activityId: activityId, catalogRevision: "")
            )
        )
        await observe(response.catalogRevision, organizationId: organizationId, branchId: branchId, activityId: activityId)
        return response
    }

    func deactivateProduct(organizationId: String, productId: String, reason: String) async throws -> BusinessProductMutationResponse {
        try await statusMutation(organizationId: organizationId, productId: productId, path: BusinessProductsRoutes.deactivate(productId), reason: reason)
    }

    func activateProduct(organizationId: String, productId: String, reason: String) async throws -> BusinessProductMutationResponse {
        try await statusMutation(organizationId: organizationId, productId: productId, path: BusinessProductsRoutes.activate(productId), reason: reason)
    }

    private func statusMutation(organizationId: String, productId: String, path: String, reason: String) async throws -> BusinessProductMutationResponse {
        try await apiClient.send(
            APIRequest<BusinessProductMutationResponse>.json(
                method: .post,
                path: path,
                body: BusinessProductStatusRequest(reason: reason),
                headers: [BusinessHeaders.organizationId: organizationId]
            )
        )
    }

    private func headers(organizationId: String, branchId: String, activityId: String, catalogRevision: String) -> [String: String] {
        var result: [String: String] = [
            BusinessHeaders.organizationId: organizationId,
            BusinessHeaders.branchId: branchId,
            BusinessHeaders.activityId: activityId
        ]
        let normalized = catalogRevision.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.isEmpty { result[BusinessHeaders.catalogRevision] = normalized }
        return result
    }

    private func observe(_ revision: String?, organizationId: String, branchId: String, activityId: String) async {
        guard let revision, !revision.isEmpty else { return }
        await revisionRegistry.observeCatalogRevision(
            organizationId: organizationId,
            branchId: branchId,
            activityId: activityId,
            catalogRevision: revision
        )
    }
}
