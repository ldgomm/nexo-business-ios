//
//  BusinessProductModels.swift
//  Nexo Business
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

struct BusinessProductUpsertRequest: Encodable, Equatable, Sendable {
    let name: String
    let description: String?
    let code: String?
    let category: String?
    let type: String
    let price: MoneyAmount
    let taxProfileCode: String?
    let branchId: String?
    let activityId: String
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
        switch status?.lowercased() {
        case "active": return "Disponible"
        case "disabled", "inactive": return "No disponible"
        default: return status ?? "Sin estado"
        }
    }
    
    var productsIsActive: Bool {
        status?.lowercased() == "active"
    }
    
    var productsPrimaryCode: String? {
        sku?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmptyForProducts
        ?? barcode?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmptyForProducts
    }
}

private extension String {
    var nilIfEmptyForProducts: String? {
        isEmpty ? nil : self
    }
}
