//
//  BusinessProductModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

typealias BusinessProduct = BusinessCatalogItem

struct BusinessProductsResponse: Decodable, Equatable, Sendable {
    let products: [BusinessProduct]
    let catalogRevision: String?
    
    private enum CodingKeys: String, CodingKey {
        case products
        case items
        case data
        case results
        case catalogRevision
    }
    
    init(products: [BusinessProduct], catalogRevision: String? = nil) {
        self.products = products
        self.catalogRevision = catalogRevision
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        products = try container.decodeIfPresent([BusinessProduct].self, forKey: .products)
        ?? container.decodeIfPresent([BusinessProduct].self, forKey: .items)
        ?? container.decodeIfPresent([BusinessProduct].self, forKey: .data)
        ?? container.decodeIfPresent([BusinessProduct].self, forKey: .results)
        ?? []
        catalogRevision = try container.decodeIfPresent(String.self, forKey: .catalogRevision)
    }
}

struct BusinessProductMutationResponse: Decodable, Equatable, Sendable {
    let product: BusinessProduct
    let catalogRevision: String?
    
    init(product: BusinessProduct, catalogRevision: String?) {
        self.product = product
        self.catalogRevision = catalogRevision
    }
    
    private enum CodingKeys: String, CodingKey {
        case product
        case item
        case data
        case catalogRevision
    }
    
    init(from decoder: Decoder) throws {
        if let direct = try? BusinessProduct(from: decoder) {
            product = direct
            catalogRevision = nil
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        product = try container.decodeIfPresent(BusinessProduct.self, forKey: .product)
        ?? container.decodeIfPresent(BusinessProduct.self, forKey: .item)
        ?? container.decode(BusinessProduct.self, forKey: .data)
        catalogRevision = try container.decodeIfPresent(String.self, forKey: .catalogRevision)
    }
}

struct BusinessMasterCatalogItemsResponse: Decodable, Equatable, Sendable {
    let items: [BusinessMasterCatalogItem]

    private enum CodingKeys: String, CodingKey {
        case items
        case products
        case data
        case results
    }

    init(items: [BusinessMasterCatalogItem]) {
        self.items = items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([BusinessMasterCatalogItem].self, forKey: .items)
        ?? container.decodeIfPresent([BusinessMasterCatalogItem].self, forKey: .products)
        ?? container.decodeIfPresent([BusinessMasterCatalogItem].self, forKey: .data)
        ?? container.decodeIfPresent([BusinessMasterCatalogItem].self, forKey: .results)
        ?? []
    }
}

struct BusinessMasterCatalogItem: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let type: String
    let categoryName: String?
    let defaultTaxProfileCode: String?
    let masterStatus: String
    let alreadyAdopted: Bool
    let existingBusinessProductId: String?
    let canAdopt: Bool
    let blockedReason: String?

    init(
        id: String,
        name: String,
        type: String = "PRODUCT",
        categoryName: String? = nil,
        defaultTaxProfileCode: String? = nil,
        masterStatus: String = "ACTIVE",
        alreadyAdopted: Bool = false,
        existingBusinessProductId: String? = nil,
        canAdopt: Bool = true,
        blockedReason: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.categoryName = categoryName
        self.defaultTaxProfileCode = defaultTaxProfileCode
        self.masterStatus = masterStatus
        self.alreadyAdopted = alreadyAdopted
        self.existingBusinessProductId = existingBusinessProductId
        self.canAdopt = canAdopt
        self.blockedReason = blockedReason
    }

    fileprivate enum CodingKeys: String, CodingKey {
        case id
        case mongoId = "_id"
        case name
        case canonicalName
        case displayName
        case type
        case categoryName
        case category
        case productFamilyId
        case defaultTaxProfileCode
        case taxProfileCode
        case masterStatus
        case status
        case alreadyAdopted
        case existingBusinessProductId
        case canAdopt
        case blockedReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFirstString(for: [.id, .mongoId])
        name = try container.decodeFirstString(for: [.name, .canonicalName, .displayName])
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "PRODUCT"
        categoryName = try container.decodeFirstStringIfPresent(for: [.categoryName, .category, .productFamilyId])
        defaultTaxProfileCode = try container.decodeFirstStringIfPresent(for: [.defaultTaxProfileCode, .taxProfileCode])
        masterStatus = try container.decodeFirstStringIfPresent(for: [.masterStatus, .status]) ?? "ACTIVE"
        alreadyAdopted = try container.decodeIfPresent(Bool.self, forKey: .alreadyAdopted) ?? false
        existingBusinessProductId = try container.decodeIfPresent(String.self, forKey: .existingBusinessProductId)
        canAdopt = try container.decodeIfPresent(Bool.self, forKey: .canAdopt) ?? !alreadyAdopted
        blockedReason = try container.decodeIfPresent(String.self, forKey: .blockedReason)
    }
}

struct BusinessTaxProfilesResponse: Decodable, Equatable, Sendable {
    let profiles: [BusinessTaxProfile]
    let defaultProductTaxProfileCode: String?

    private enum CodingKeys: String, CodingKey {
        case profiles
        case taxProfiles
        case items
        case data
        case defaultProductTaxProfileCode
    }

    init(profiles: [BusinessTaxProfile], defaultProductTaxProfileCode: String? = nil) {
        self.profiles = profiles
        self.defaultProductTaxProfileCode = defaultProductTaxProfileCode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profiles = try container.decodeIfPresent([BusinessTaxProfile].self, forKey: .profiles)
        ?? container.decodeIfPresent([BusinessTaxProfile].self, forKey: .taxProfiles)
        ?? container.decodeIfPresent([BusinessTaxProfile].self, forKey: .items)
        ?? container.decodeIfPresent([BusinessTaxProfile].self, forKey: .data)
        ?? []
        defaultProductTaxProfileCode = try container.decodeIfPresent(String.self, forKey: .defaultProductTaxProfileCode)
    }
}

struct BusinessTaxProfile: Decodable, Equatable, Identifiable, Sendable {
    var id: String { code }
    let code: String
    let displayName: String
    let treatment: String?
    let rateLabel: String?
    let enabled: Bool
    let defaultForProducts: Bool
    let canUseForProducts: Bool
    let internalOnly: Bool
    let helpText: String?

    init(
        code: String,
        displayName: String,
        treatment: String? = nil,
        rateLabel: String? = nil,
        enabled: Bool = true,
        defaultForProducts: Bool = false,
        canUseForProducts: Bool = true,
        internalOnly: Bool = false,
        helpText: String? = nil
    ) {
        self.code = code
        self.displayName = displayName
        self.treatment = treatment
        self.rateLabel = rateLabel
        self.enabled = enabled
        self.defaultForProducts = defaultForProducts
        self.canUseForProducts = canUseForProducts
        self.internalOnly = internalOnly
        self.helpText = helpText
    }

    var pickerTitle: String {
        if let rateLabel, !rateLabel.isEmpty {
            return "\(displayName) · \(rateLabel)"
        }
        return displayName
    }
}

struct BusinessProductAdoptRequest: Encodable, Equatable, Sendable {
    let masterCatalogItemId: String
    let branchId: String?
    let activityId: String
    let price: MoneyAmount
    let taxProfileCode: String?
    let localCode: String?
    let localName: String?
    let reason: String
}

struct BusinessProductPatchRequest: Encodable, Equatable, Sendable {
    let name: String?
    let description: String?
    let code: String?
    let category: String?
    let price: MoneyAmount?
    let taxProfileCode: String?
    let reason: String
}

struct BusinessProductStatusRequest: Encodable, Equatable, Sendable {
    let reason: String
}

extension BusinessProduct {
    var productsDisplayPrice: String {
        guard let amount = price else { return "Sin precio" }
        return "$\(amount.amount)"
    }
    
    var productsDisplayStatus: String {
        if let availabilityLabel, !availabilityLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return availabilityLabel
        }

        switch effectiveStatus?.lowercased() {
        case "available": return "Disponible"
        case "paused_by_business": return "Pausado por negocio"
        case "out_of_stock_by_business": return "Sin stock"
        case "archived_by_business": return "Archivado por negocio"
        case "draft_by_master": return "En preparación por catálogo"
        case "paused_by_master", "blocked_by_master", "disabled_by_master": return "Pausado por catálogo"
        case "removed_by_master": return "Retirado por catálogo"
        case "legacy_needs_review", "local_needs_review": return "Requiere revisión"
        case "removed_from_account": return "Removido"
        default: break
        }

        switch status?.lowercased() {
        case "active": return "Disponible"
        case "paused", "disabled", "inactive", "out_of_stock": return "No disponible"
        case "removed_from_account", "archived": return "Removido"
        default: return status ?? "Sin estado"
        }
    }
    
    var productsIsActive: Bool {
        if let canSell {
            return canSell
        }
        if let effectiveStatus {
            return effectiveStatus.lowercased() == "available"
        }
        return status?.lowercased() == "active"
    }

    var productsCanActivate: Bool {
        canActivate ?? !productsIsActive
    }

    var productsCanDeactivate: Bool {
        canDeactivate ?? productsIsActive
    }

    var productsAvailabilityReason: String? {
        availabilityReason?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmptyForProducts
    }
    
    var productsPrimaryCode: String? {
        sku?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmptyForProducts
        ?? barcode?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmptyForProducts
    }

    var productsMasterReferenceLabel: String? {
        masterCatalogItemId?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmptyForProducts.map { "Catálogo: \($0)" }
    }
}

private extension String {
    var nilIfEmptyForProducts: String? {
        isEmpty ? nil : self
    }
}

private extension KeyedDecodingContainer where Key == BusinessMasterCatalogItem.CodingKeys {
    func decodeFirstString(for keys: [BusinessMasterCatalogItem.CodingKeys]) throws -> String {
        for key in keys {
            if let value = try decodeIfPresent(String.self, forKey: key), !value.isEmpty {
                return value
            }
        }
        throw DecodingError.keyNotFound(
            keys.first ?? .id,
            DecodingError.Context(codingPath: codingPath, debugDescription: "Expected one of \(keys.map(\.stringValue))")
        )
    }

    func decodeFirstStringIfPresent(for keys: [BusinessMasterCatalogItem.CodingKeys]) throws -> String? {
        for key in keys {
            if let value = try decodeIfPresent(String.self, forKey: key), !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return nil
    }
}
