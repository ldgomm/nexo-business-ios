//
//  ProductsRepository.swift
//  Nexo Business
//

import Foundation

protocol ProductsRepository: Sendable {
    func listTaxProfiles(organizationId: String) async throws -> BusinessTaxProfilesResponse

    func listProducts(
        organizationId: String,
        branchId: String,
        activityId: String,
        catalogRevision: String,
        query: String,
        status: String?,
        limit: Int
    ) async throws -> BusinessProductsResponse

    func createProduct(
        organizationId: String,
        branchId: String,
        activityId: String,
        request: BusinessProductUpsertRequest
    ) async throws -> BusinessProductMutationResponse

    func updateProduct(
        organizationId: String,
        branchId: String,
        activityId: String,
        productId: String,
        request: BusinessProductPatchRequest
    ) async throws -> BusinessProductMutationResponse

    func deactivateProduct(
        organizationId: String,
        productId: String,
        reason: String
    ) async throws -> BusinessProductMutationResponse

    func activateProduct(
        organizationId: String,
        productId: String,
        reason: String
    ) async throws -> BusinessProductMutationResponse
}

final class PreviewProductsRepository: ProductsRepository, @unchecked Sendable {
    private let previewTaxProfiles = [
        BusinessTaxProfile(
            code: "iva_full",
            displayName: "IVA vigente",
            treatment: "IVA_FULL",
            rateLabel: "Servidor",
            defaultForProducts: true,
            helpText: "Perfil tributario de prueba. El servidor calcula la tarifa real."
        ),
        BusinessTaxProfile(
            code: "iva_zero",
            displayName: "IVA 0%",
            treatment: "IVA_ZERO",
            rateLabel: "0%"
        )
    ]

    private var storage: [BusinessProduct] = [
        BusinessProduct(
            id: "prod_cuy",
            name: "Cuy entero",
            itemDescription: "Plato principal",
            sku: "CUY-ENTERO",
            type: "PRODUCT",
            status: "ACTIVE",
            price: MoneyAmount(amount: "24.00", currency: "USD"),
            taxProfileCode: "iva_full",
            taxProfileId: "iva_full"
        ),
        BusinessProduct(
            id: "prod_borrego",
            name: "Borrego",
            itemDescription: "Plato principal",
            sku: "BORREGO",
            type: "PRODUCT",
            status: "ACTIVE",
            price: MoneyAmount(amount: "10.00", currency: "USD"),
            taxProfileCode: "iva_full",
            taxProfileId: "iva_full"
        )
    ]

    func listTaxProfiles(organizationId: String) async throws -> BusinessTaxProfilesResponse {
        BusinessTaxProfilesResponse(profiles: previewTaxProfiles, defaultProductTaxProfileCode: "iva_full")
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
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = storage.filter { product in
            let matchesQuery = normalized.isEmpty || product.name.lowercased().contains(normalized) || (product.productsPrimaryCode?.lowercased().contains(normalized) == true)
            let matchesStatus = status == nil || status == "all" || product.status?.lowercased() == status?.lowercased()
            return matchesQuery && matchesStatus
        }
        return BusinessProductsResponse(products: Array(filtered.prefix(limit)), catalogRevision: catalogRevision)
    }

    func createProduct(organizationId: String, branchId: String, activityId: String, request: BusinessProductUpsertRequest) async throws -> BusinessProductMutationResponse {
        let resolvedTaxProfileCode = request.taxProfileCode ?? previewTaxProfiles.first(where: { $0.defaultForProducts })?.code ?? previewTaxProfiles.first?.code
        let product = BusinessProduct(
            id: "prod_preview_\(UUID().uuidString.prefix(8))",
            name: request.name,
            itemDescription: request.description,
            sku: request.code,
            type: request.type,
            status: "ACTIVE",
            price: request.price,
            taxProfileCode: resolvedTaxProfileCode,
            taxProfileId: resolvedTaxProfileCode
        )
        storage.append(product)
        return BusinessProductMutationResponse(
            product: product,
            catalogRevision: nil
        )
    }

    func updateProduct(organizationId: String, branchId: String, activityId: String, productId: String, request: BusinessProductPatchRequest) async throws -> BusinessProductMutationResponse {
        guard let index = storage.firstIndex(where: { $0.id == productId }) else { throw ProductsPreviewError.notFound }
        let current = storage[index]
        let product = BusinessProduct(
            id: current.id,
            name: request.name ?? current.name,
            itemDescription: request.description ?? current.itemDescription,
            sku: request.code ?? current.sku,
            barcode: current.barcode,
            type: current.type,
            status: current.status,
            unit: current.unit,
            price: request.price ?? current.price,
            taxProfileCode: request.taxProfileCode ?? current.taxProfileCode,
            taxProfileName: current.taxProfileName,
            taxProfileId: request.taxProfileCode ?? current.taxProfileId,
            availableStock: current.availableStock,
            allowsDecimalQuantity: current.allowsDecimalQuantity
        )
        storage[index] = product
        return BusinessProductMutationResponse(
            product: product,
            catalogRevision: nil
        )
    }

    func deactivateProduct(organizationId: String, productId: String, reason: String) async throws -> BusinessProductMutationResponse {
        try await setStatus(productId: productId, status: "DISABLED")
    }

    func activateProduct(organizationId: String, productId: String, reason: String) async throws -> BusinessProductMutationResponse {
        try await setStatus(productId: productId, status: "ACTIVE")
    }

    private func setStatus(productId: String, status: String) async throws -> BusinessProductMutationResponse {
        guard let index = storage.firstIndex(where: { $0.id == productId }) else { throw ProductsPreviewError.notFound }
        let current = storage[index]
        let product = BusinessProduct(
            id: current.id,
            name: current.name,
            itemDescription: current.itemDescription,
            sku: current.sku,
            barcode: current.barcode,
            type: current.type,
            status: status,
            unit: current.unit,
            price: current.price,
            taxProfileCode: current.taxProfileCode,
            taxProfileName: current.taxProfileName,
            taxProfileId: current.taxProfileId,
            availableStock: current.availableStock,
            allowsDecimalQuantity: current.allowsDecimalQuantity
        )
        storage[index] = product
        return BusinessProductMutationResponse(
            product: product,
            catalogRevision: nil
        )
    }
}

private enum ProductsPreviewError: Error { case notFound }

//private struct PreviewProductMutationEnvelope: Encodable { //Type 'PreviewProductMutationEnvelope' does not conform to protocol 'Encodable'
//    let product: BusinessProduct
//    let catalogRevision: String?
//}
