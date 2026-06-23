//
//  ProductsRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
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

    func searchMasterCatalogItems(
        organizationId: String,
        branchId: String,
        activityId: String,
        query: String,
        type: String?,
        limit: Int
    ) async throws -> BusinessMasterCatalogItemsResponse

    func adoptProduct(
        organizationId: String,
        branchId: String,
        activityId: String,
        request: BusinessProductAdoptRequest
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

    private let masterItems: [BusinessMasterCatalogItem] = [
        BusinessMasterCatalogItem(id: "master_cuy", name: "Cuy entero", type: "PRODUCT", categoryName: "Platos fuertes", defaultTaxProfileCode: "iva_full"),
        BusinessMasterCatalogItem(id: "master_borrego", name: "Borrego", type: "PRODUCT", categoryName: "Platos fuertes", defaultTaxProfileCode: "iva_full"),
        BusinessMasterCatalogItem(id: "master_jugo", name: "Jarra de jugo", type: "PRODUCT", categoryName: "Bebidas", defaultTaxProfileCode: "iva_zero")
    ]

    private var storage: [BusinessProduct] = [
        BusinessProduct(
            id: "prod_cuy",
            name: "Cuy entero",
            itemDescription: "Plato principal",
            sku: "CUY-ENTERO",
            type: "PRODUCT",
            status: "ACTIVE",
            localStatus: "ACTIVE",
            masterStatus: "ACTIVE",
            effectiveStatus: "AVAILABLE",
            availabilityLabel: "Disponible",
            source: "MASTER_ADOPTION",
            masterCatalogItemId: "master_cuy",
            canActivate: false,
            canDeactivate: true,
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
            localStatus: "ACTIVE",
            masterStatus: "ACTIVE",
            effectiveStatus: "AVAILABLE",
            availabilityLabel: "Disponible",
            source: "MASTER_ADOPTION",
            masterCatalogItemId: "master_borrego",
            canActivate: false,
            canDeactivate: true,
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
            let normalizedStatus = status?.lowercased()
            let matchesStatus = normalizedStatus == nil
            || normalizedStatus == "all"
            || (normalizedStatus == "active" && product.productsIsActive)
            || (normalizedStatus == "disabled" && !product.productsIsActive)
            return matchesQuery && matchesStatus
        }
        return BusinessProductsResponse(products: Array(filtered.prefix(limit)), catalogRevision: catalogRevision)
    }

    func searchMasterCatalogItems(
        organizationId: String,
        branchId: String,
        activityId: String,
        query: String,
        type: String?,
        limit: Int
    ) async throws -> BusinessMasterCatalogItemsResponse {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let items = masterItems.map { item -> BusinessMasterCatalogItem in
            let existing = storage.first { $0.masterCatalogItemId == item.id }
            return BusinessMasterCatalogItem(
                id: item.id,
                name: item.name,
                type: item.type,
                categoryName: item.categoryName,
                defaultTaxProfileCode: item.defaultTaxProfileCode,
                masterStatus: item.masterStatus,
                alreadyAdopted: existing != nil,
                existingBusinessProductId: existing?.id,
                canAdopt: existing == nil && item.canAdopt,
                blockedReason: existing == nil ? item.blockedReason : "Ya fue agregado a este negocio."
            )
        }.filter { item in
            let matchesQuery = normalized.isEmpty || item.name.lowercased().contains(normalized) || item.id.lowercased().contains(normalized)
            let matchesType = type == nil || item.type.lowercased() == type?.lowercased()
            return matchesQuery && matchesType
        }
        return BusinessMasterCatalogItemsResponse(items: Array(items.prefix(limit)))
    }

    func adoptProduct(organizationId: String, branchId: String, activityId: String, request: BusinessProductAdoptRequest) async throws -> BusinessProductMutationResponse {
        guard let master = masterItems.first(where: { $0.id == request.masterCatalogItemId }) else { throw ProductsPreviewError.notFound }
        if storage.contains(where: { $0.masterCatalogItemId == master.id }) { throw ProductsPreviewError.duplicate }
        let resolvedTaxProfileCode = request.taxProfileCode ?? master.defaultTaxProfileCode ?? previewTaxProfiles.first(where: { $0.defaultForProducts })?.code ?? previewTaxProfiles.first?.code
        let product = BusinessProduct(
            id: "prod_preview_\(UUID().uuidString.prefix(8))",
            name: request.localName?.nilIfEmptyForPreviewProducts ?? master.name,
            itemDescription: nil,
            sku: request.localCode,
            type: master.type,
            status: "ACTIVE",
            localStatus: "ACTIVE",
            masterStatus: "ACTIVE",
            effectiveStatus: "AVAILABLE",
            availabilityLabel: "Disponible",
            source: "MASTER_ADOPTION",
            masterCatalogItemId: master.id,
            canActivate: false,
            canDeactivate: true,
            price: request.price,
            taxProfileCode: resolvedTaxProfileCode,
            taxProfileId: resolvedTaxProfileCode
        )
        storage.append(product)
        return BusinessProductMutationResponse(product: product, catalogRevision: nil)
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
            localStatus: current.localStatus,
            masterStatus: current.masterStatus,
            effectiveStatus: current.effectiveStatus,
            availabilityLabel: current.availabilityLabel,
            source: current.source,
            masterCatalogItemId: current.masterCatalogItemId,
            canActivate: current.canActivate,
            canDeactivate: current.canDeactivate,
            unit: current.unit,
            price: request.price ?? current.price,
            taxProfileCode: request.taxProfileCode ?? current.taxProfileCode,
            taxProfileName: current.taxProfileName,
            taxProfileId: request.taxProfileCode ?? current.taxProfileId,
            availableStock: current.availableStock,
            allowsDecimalQuantity: current.allowsDecimalQuantity
        )
        storage[index] = product
        return BusinessProductMutationResponse(product: product, catalogRevision: nil)
    }

    func deactivateProduct(organizationId: String, productId: String, reason: String) async throws -> BusinessProductMutationResponse {
        try await setStatus(productId: productId, status: "PAUSED", effectiveStatus: "PAUSED_BY_BUSINESS", label: "No disponible")
    }

    func activateProduct(organizationId: String, productId: String, reason: String) async throws -> BusinessProductMutationResponse {
        try await setStatus(productId: productId, status: "ACTIVE", effectiveStatus: "AVAILABLE", label: "Disponible")
    }

    private func setStatus(productId: String, status: String, effectiveStatus: String, label: String) async throws -> BusinessProductMutationResponse {
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
            localStatus: status,
            masterStatus: current.masterStatus,
            effectiveStatus: effectiveStatus,
            availabilityLabel: label,
            source: current.source,
            masterCatalogItemId: current.masterCatalogItemId,
            canActivate: status != "ACTIVE",
            canDeactivate: status == "ACTIVE",
            unit: current.unit,
            price: current.price,
            taxProfileCode: current.taxProfileCode,
            taxProfileName: current.taxProfileName,
            taxProfileId: current.taxProfileId,
            availableStock: current.availableStock,
            allowsDecimalQuantity: current.allowsDecimalQuantity
        )
        storage[index] = product
        return BusinessProductMutationResponse(product: product, catalogRevision: nil)
    }
}

private enum ProductsPreviewError: Error { case notFound, duplicate }

private extension String {
    var nilIfEmptyForPreviewProducts: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
