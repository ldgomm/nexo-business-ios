//
//  CatalogModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

struct BusinessCatalogUnit: Decodable, Equatable, Sendable {
    let code: String?
    let name: String?
    let allowsDecimal: Bool?

    init(
        code: String? = nil,
        name: String? = nil,
        allowsDecimal: Bool? = nil
    ) {
        self.code = code
        self.name = name
        self.allowsDecimal = allowsDecimal
    }

    private enum CodingKeys: String, CodingKey {
        case code
        case name
        case allowsDecimal
    }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let value = try? single.decode(String.self) {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            self.code = BusinessCatalogUnit.normalizedCode(from: normalized)
            self.name = normalized.isEmpty ? nil : normalized
            self.allowsDecimal = false
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawCode = try container.decodeIfPresent(String.self, forKey: .code)
        let rawName = try container.decodeIfPresent(String.self, forKey: .name)
        self.code = rawCode.map(BusinessCatalogUnit.normalizedCode(from:))
            ?? rawName.map(BusinessCatalogUnit.normalizedCode(from:))
        self.name = rawName ?? rawCode
        self.allowsDecimal = try container.decodeIfPresent(Bool.self, forKey: .allowsDecimal)
    }

    private static func normalizedCode(from value: String) -> String {
        let lower = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch lower {
        case "unidad", "unidades", "unit", "u", "und":
            return "unit"
        default:
            return lower
        }
    }
}

struct CatalogIdentifier: Decodable, Equatable, Sendable {
    let type: String
    let value: String
    let normalizedValue: String?
    let scope: String?
    let status: String?
    let source: String?
    let isPrimary: Bool?
}


struct BusinessCatalogMediaAsset: Decodable, Equatable, Sendable {
    let id: String?
    let ownerKind: String?
    let url: String?
    let type: String?
    let role: String?
    let storageProvider: String?
    let bucket: String?
    let objectPath: String?
    let publicUrl: String?
    let signedUrlRequired: Bool?
    let mimeType: String?
    let sizeBytes: Int?
    let checksumSha256: String?
    let width: Int?
    let height: Int?
    let altText: String?
    let sortOrder: Int?
    let status: String?

    var safeDisplayUrl: String? {
        publicUrl?.nilIfEmptyForCatalog ?? url?.nilIfEmptyForCatalog ?? objectPath?.nilIfEmptyForCatalog
    }
}

struct BusinessCatalogRelatedItem: Decodable, Equatable, Sendable {
    let id: String?
    let relatedItemId: String?
    let targetItemId: String?
    let relationType: String?
    let priority: Int?
    let type: String?
    let reason: String?
    let sortOrder: Int?
    let status: String?
}

struct BusinessCatalogBundleComponent: Decodable, Equatable, Sendable {
    let catalogItemId: String
    let quantity: String?
    let required: Bool?
    let displayNameOverride: String?
}

struct BusinessCatalogPriceListEntry: Decodable, Equatable, Sendable {
    let priceListId: String?
    let label: String?
    let price: MoneyAmount?
    let kind: String?
    let active: Bool?
}

struct BusinessCatalogPromotionEligibility: Decodable, Equatable, Sendable {
    let eligibleForPromotions: Bool?
    let eligibleForCoupons: Bool?
    let eligibleForBundleOffers: Bool?
    let promotionTags: [String]?
}

struct BusinessCatalogDiscountPolicy: Decodable, Equatable, Sendable {
    let discountAllowed: Bool?
    let requiresManagerApproval: Bool?
    let maxManualDiscountPercent: String?
}

struct BusinessCatalogBundleDefinition: Decodable, Equatable, Sendable {
    let kind: String?
    let components: [BusinessCatalogBundleComponent]
    let pricingMode: String?
    let inventoryMode: String?
    let isOperationallyReady: Bool?

    init(
        kind: String? = nil,
        components: [BusinessCatalogBundleComponent] = [],
        pricingMode: String? = nil,
        inventoryMode: String? = nil,
        isOperationallyReady: Bool? = nil
    ) {
        self.kind = kind
        self.components = components
        self.pricingMode = pricingMode
        self.inventoryMode = inventoryMode
        self.isOperationallyReady = isOperationallyReady
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case components
        case pricingMode
        case inventoryMode
        case isOperationallyReady
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.kind = try container.decodeIfPresent(String.self, forKey: .kind)
        self.components = try container.decodeIfPresent([BusinessCatalogBundleComponent].self, forKey: .components) ?? []
        self.pricingMode = try container.decodeIfPresent(String.self, forKey: .pricingMode)
        self.inventoryMode = try container.decodeIfPresent(String.self, forKey: .inventoryMode)
        self.isOperationallyReady = try container.decodeIfPresent(Bool.self, forKey: .isOperationallyReady)
    }
}

struct BusinessCatalogMetadataSnapshot: Decodable, Equatable, Sendable {
    let rawKeys: [String]
    let priceListEntries: [BusinessCatalogPriceListEntry]
    let promotionEligibility: BusinessCatalogPromotionEligibility?
    let discountPolicy: BusinessCatalogDiscountPolicy?
    let tags: [String]
    let publicTitle: String?
    let publicDescription: String?
    let searchKeywords: [String]
    let isFeatured: Bool?
    let isNewArrival: Bool?
    let isBestSeller: Bool?
    let isPubliclyVisible: Bool?

    static let empty = BusinessCatalogMetadataSnapshot(rawKeys: [])

    init(
        rawKeys: [String] = [],
        priceListEntries: [BusinessCatalogPriceListEntry] = [],
        promotionEligibility: BusinessCatalogPromotionEligibility? = nil,
        discountPolicy: BusinessCatalogDiscountPolicy? = nil,
        tags: [String] = [],
        publicTitle: String? = nil,
        publicDescription: String? = nil,
        searchKeywords: [String] = [],
        isFeatured: Bool? = nil,
        isNewArrival: Bool? = nil,
        isBestSeller: Bool? = nil,
        isPubliclyVisible: Bool? = nil
    ) {
        self.rawKeys = rawKeys
        self.priceListEntries = priceListEntries
        self.promotionEligibility = promotionEligibility
        self.discountPolicy = discountPolicy
        self.tags = tags
        self.publicTitle = publicTitle
        self.publicDescription = publicDescription
        self.searchKeywords = searchKeywords
        self.isFeatured = isFeatured
        self.isNewArrival = isNewArrival
        self.isBestSeller = isBestSeller
        self.isPubliclyVisible = isPubliclyVisible
    }

    init(from decoder: Decoder) throws {
        guard let container = try? decoder.container(keyedBy: CatalogDynamicCodingKey.self) else {
            self.init()
            return
        }

        let rawKeys = container.allKeys.map(\.stringValue).sorted()
        let priceListEntries = try container.decodeIfPresent([BusinessCatalogPriceListEntry].self, forKey: CatalogDynamicCodingKey("priceListEntries")) ?? []
        let promotionEligibility = try container.decodeIfPresent(BusinessCatalogPromotionEligibility.self, forKey: CatalogDynamicCodingKey("promotionEligibility"))
        let discountPolicy = try container.decodeIfPresent(BusinessCatalogDiscountPolicy.self, forKey: CatalogDynamicCodingKey("discountPolicy"))
        let tags = try container.decodeIfPresent([String].self, forKey: CatalogDynamicCodingKey("tags")) ?? []
        let publicTitle = try container.decodeIfPresent(String.self, forKey: CatalogDynamicCodingKey("publicTitle"))
        let publicDescription = try container.decodeIfPresent(String.self, forKey: CatalogDynamicCodingKey("publicDescription"))
        let searchKeywords = try container.decodeIfPresent([String].self, forKey: CatalogDynamicCodingKey("searchKeywords")) ?? []
        let isFeatured = try container.decodeIfPresent(Bool.self, forKey: CatalogDynamicCodingKey("isFeatured"))
        let isNewArrival = try container.decodeIfPresent(Bool.self, forKey: CatalogDynamicCodingKey("isNewArrival"))
        let isBestSeller = try container.decodeIfPresent(Bool.self, forKey: CatalogDynamicCodingKey("isBestSeller"))
        let isPubliclyVisible = try container.decodeIfPresent(Bool.self, forKey: CatalogDynamicCodingKey("isPubliclyVisible"))

        self.init(
            rawKeys: rawKeys,
            priceListEntries: priceListEntries,
            promotionEligibility: promotionEligibility,
            discountPolicy: discountPolicy,
            tags: tags,
            publicTitle: publicTitle,
            publicDescription: publicDescription,
            searchKeywords: searchKeywords,
            isFeatured: isFeatured,
            isNewArrival: isNewArrival,
            isBestSeller: isBestSeller,
            isPubliclyVisible: isPubliclyVisible
        )
    }

    var hasContent: Bool {
        !rawKeys.isEmpty || !priceListEntries.isEmpty || promotionEligibility != nil || discountPolicy != nil ||
        !tags.isEmpty || publicTitle != nil || publicDescription != nil || !searchKeywords.isEmpty ||
        isFeatured != nil || isNewArrival != nil || isBestSeller != nil || isPubliclyVisible != nil
    }
}

private struct CatalogDynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

struct PlatformCatalogTemplateSuggestion: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let globalCatalogId: String
    let canonicalName: String
    let normalizedName: String?
    let type: String
    let status: String
    let productFamilyId: String?
    let variantAttributes: [String: String]
    let identifiers: [CatalogIdentifier]
    let attributes: [String: String]

    var displayName: String {
        canonicalName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var primaryCode: String? {
        identifiers.first(where: { $0.isPrimary == true })?.value
            ?? identifiers.first?.value
            ?? attributes["sku"]
            ?? attributes["code"]
    }

    var suggestedPrice: MoneyAmount? {
        let candidates = [
            attributes["suggestedPrice"],
            attributes["suggestedPriceAmount"],
            attributes["price"],
        ]

        guard let raw = candidates.compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) }).first(where: { !$0.isEmpty }) else {
            return nil
        }

        return MoneyAmount(amount: raw, currency: attributes["suggestedCurrency"] ?? "USD")
    }

    var suggestedTaxProfileCode: String? {
        [
            attributes["defaultTaxProfileCode"],
            attributes["suggestedTaxProfileCode"],
            attributes["taxProfileCode"],
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first(where: { !$0.isEmpty })
    }

    var suggestedCategoryCode: String? {
        attributes["suggestedCategoryCode"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmptyForCatalog
    }

    var canAdoptFromBusiness: Bool {
        suggestedPrice != nil && suggestedTaxProfileCode != nil && status.lowercased() == "active"
    }
}

struct CatalogSuggestionSearchResponse: Decodable, Equatable, Sendable {
    let templates: [PlatformCatalogTemplateSuggestion]

    init(templates: [PlatformCatalogTemplateSuggestion]) {
        self.templates = templates
    }

    private enum CodingKeys: String, CodingKey {
        case templates
        case items
        case results
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        templates = try container.decodeIfPresent([PlatformCatalogTemplateSuggestion].self, forKey: .templates)
            ?? container.decodeIfPresent([PlatformCatalogTemplateSuggestion].self, forKey: .items)
            ?? container.decodeIfPresent([PlatformCatalogTemplateSuggestion].self, forKey: .results)
            ?? container.decodeIfPresent([PlatformCatalogTemplateSuggestion].self, forKey: .data)
            ?? []
    }
}

struct CatalogCopyFromTemplateRequest: Encodable, Equatable, Sendable {
    let templateId: String
    let branchId: String?
    let activityId: String
    let localPrice: MoneyAmount
    let taxProfileCode: String
    let reason: String
}

struct BusinessCatalogItem: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let itemDescription: String?
    let displayName: String?
    let shortDescription: String?
    let publicDescription: String?
    let sku: String?
    let barcode: String?
    let type: String?
    let status: String?
    let localStatus: String?
    let masterStatus: String?
    let effectiveStatus: String?
    let availabilityLabel: String?
    let availabilityReason: String?
    let source: String?
    let masterCatalogItemId: String?
    let canSell: Bool?
    let canActivate: Bool?
    let canDeactivate: Bool?
    let requiresReview: Bool?
    let unit: BusinessCatalogUnit?
    let price: MoneyAmount?
    let compareAtPrice: MoneyAmount?
    let cost: MoneyAmount?
    let brandId: String?
    let categoryId: String?
    let unitId: String?
    let publicDiscoveryStatus: String?
    let productFamilyId: String?
    let parentProductId: String?
    let variantAttributes: [String: String]
    let identifiers: [CatalogIdentifier]
    let alternateCodes: [String]
    let tags: [String]
    let media: [BusinessCatalogMediaAsset]
    let relatedItems: [BusinessCatalogRelatedItem]
    let bundle: BusinessCatalogBundleDefinition?
    let pricingMetadata: BusinessCatalogMetadataSnapshot
    let commercialMetadata: BusinessCatalogMetadataSnapshot
    let readinessWarnings: [String]
    let taxProfileCode: String?
    let taxProfileName: String?
    let taxProfileId: String?
    let tracksInventory: Bool?
    let hasStockProfile: Bool?
    let stockStatus: String?
    let availableStock: String?
    let allowNegativeStock: Bool?
    let blockSaleWhenInsufficientStock: Bool?
    let allowsDecimalQuantity: Bool?
    let attributes: [String: String]

    init(
        id: String,
        name: String,
        itemDescription: String? = nil,
        displayName: String? = nil,
        shortDescription: String? = nil,
        publicDescription: String? = nil,
        sku: String? = nil,
        barcode: String? = nil,
        type: String? = nil,
        status: String? = nil,
        localStatus: String? = nil,
        masterStatus: String? = nil,
        effectiveStatus: String? = nil,
        availabilityLabel: String? = nil,
        availabilityReason: String? = nil,
        source: String? = nil,
        masterCatalogItemId: String? = nil,
        canSell: Bool? = nil,
        canActivate: Bool? = nil,
        canDeactivate: Bool? = nil,
        requiresReview: Bool? = nil,
        unit: BusinessCatalogUnit? = nil,
        price: MoneyAmount? = nil,
        compareAtPrice: MoneyAmount? = nil,
        cost: MoneyAmount? = nil,
        brandId: String? = nil,
        categoryId: String? = nil,
        unitId: String? = nil,
        publicDiscoveryStatus: String? = nil,
        productFamilyId: String? = nil,
        parentProductId: String? = nil,
        variantAttributes: [String: String] = [:],
        identifiers: [CatalogIdentifier] = [],
        alternateCodes: [String] = [],
        tags: [String] = [],
        media: [BusinessCatalogMediaAsset] = [],
        relatedItems: [BusinessCatalogRelatedItem] = [],
        bundle: BusinessCatalogBundleDefinition? = nil,
        pricingMetadata: BusinessCatalogMetadataSnapshot = .empty,
        commercialMetadata: BusinessCatalogMetadataSnapshot = .empty,
        readinessWarnings: [String] = [],
        taxProfileCode: String? = nil,
        taxProfileName: String? = nil,
        taxProfileId: String? = nil,
        tracksInventory: Bool? = nil,
        hasStockProfile: Bool? = nil,
        stockStatus: String? = nil,
        availableStock: String? = nil,
        allowNegativeStock: Bool? = nil,
        blockSaleWhenInsufficientStock: Bool? = nil,
        allowsDecimalQuantity: Bool? = nil,
        attributes: [String: String] = [:],
    ) {
        self.id = id
        self.name = name
        self.itemDescription = itemDescription
        self.displayName = displayName
        self.shortDescription = shortDescription
        self.publicDescription = publicDescription
        self.sku = sku
        self.barcode = barcode
        self.type = type
        self.status = status
        self.localStatus = localStatus
        self.masterStatus = masterStatus
        self.effectiveStatus = effectiveStatus
        self.availabilityLabel = availabilityLabel
        self.availabilityReason = availabilityReason
        self.source = source
        self.masterCatalogItemId = masterCatalogItemId
        self.canSell = canSell
        self.canActivate = canActivate
        self.canDeactivate = canDeactivate
        self.requiresReview = requiresReview
        self.unit = unit
        self.price = price
        self.compareAtPrice = compareAtPrice
        self.cost = cost
        self.brandId = brandId
        self.categoryId = categoryId
        self.unitId = unitId
        self.publicDiscoveryStatus = publicDiscoveryStatus
        self.productFamilyId = productFamilyId
        self.parentProductId = parentProductId
        self.variantAttributes = variantAttributes
        self.identifiers = identifiers
        self.alternateCodes = alternateCodes
        self.tags = tags
        self.media = media
        self.relatedItems = relatedItems
        self.bundle = bundle
        self.pricingMetadata = pricingMetadata
        self.commercialMetadata = commercialMetadata
        self.readinessWarnings = readinessWarnings
        self.taxProfileCode = taxProfileCode
        self.taxProfileName = taxProfileName
        self.taxProfileId = taxProfileId
        self.tracksInventory = tracksInventory
        self.hasStockProfile = hasStockProfile
        self.stockStatus = stockStatus
        self.availableStock = availableStock
        self.allowNegativeStock = allowNegativeStock
        self.blockSaleWhenInsufficientStock = blockSaleWhenInsufficientStock
        self.allowsDecimalQuantity = allowsDecimalQuantity
        self.attributes = attributes
    }

    fileprivate enum CodingKeys: String, CodingKey {
        case id
        case mongoId = "_id"
        case name
        case localName
        case displayName
        case shortDescription
        case description
        case publicDescription
        case localDescription
        case sku
        case barcode
        case type
        case status
        case localStatus
        case masterStatus
        case effectiveStatus
        case availabilityLabel
        case availabilityReason
        case source
        case sourceType
        case masterCatalogItemId
        case templateId
        case canSell
        case availableForSale
        case canActivate
        case canDeactivate
        case requiresReview
        case unit
        case price
        case basePrice
        case unitPrice
        case localPrice
        case compareAtPrice
        case cost
        case brandId
        case categoryId
        case unitId
        case publicDiscoveryStatus
        case productFamilyId
        case parentProductId
        case variantAttributes
        case identifiers
        case alternateCodes
        case tags
        case media
        case relatedItems
        case bundle
        case pricingMetadata
        case commercialMetadata
        case readinessWarnings
        case taxProfileCode
        case defaultTaxProfileCode
        case suggestedTaxProfileCode
        case taxProfileName
        case taxProfileId
        case tracksInventory
        case hasStockProfile
        case stockStatus
        case availableStock
        case stock
        case allowNegativeStock
        case blockSaleWhenInsufficientStock
        case allowsDecimalQuantity
        case attributes
        case restaurantAttributes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFirstString(for: [.id, .mongoId])
        name = try container.decodeFirstString(for: [.name, .localName, .displayName])
        displayName = try container.decodeFirstStringIfPresent(for: [.displayName])
        shortDescription = try container.decodeFirstStringIfPresent(for: [.shortDescription])
        publicDescription = try container.decodeFirstStringIfPresent(for: [.publicDescription])
        let decodedDescription = try container.decodeFirstStringIfPresent(for: [.description, .publicDescription, .localDescription])
        itemDescription = shortDescription ?? decodedDescription
        sku = try container.decodeIfPresent(String.self, forKey: .sku)
        barcode = try container.decodeIfPresent(String.self, forKey: .barcode)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        localStatus = try container.decodeIfPresent(String.self, forKey: .localStatus)
        masterStatus = try container.decodeIfPresent(String.self, forKey: .masterStatus)
        effectiveStatus = try container.decodeIfPresent(String.self, forKey: .effectiveStatus)
        availabilityLabel = try container.decodeIfPresent(String.self, forKey: .availabilityLabel)
        availabilityReason = try container.decodeIfPresent(String.self, forKey: .availabilityReason)
        source = try container.decodeFirstStringIfPresent(for: [.source, .sourceType])
        masterCatalogItemId = try container.decodeFirstStringIfPresent(for: [.masterCatalogItemId, .templateId])
        canSell = try container.decodeIfPresent(Bool.self, forKey: .canSell)
        ?? container.decodeIfPresent(Bool.self, forKey: .availableForSale)
        canActivate = try container.decodeIfPresent(Bool.self, forKey: .canActivate)
        canDeactivate = try container.decodeIfPresent(Bool.self, forKey: .canDeactivate)
        requiresReview = try container.decodeIfPresent(Bool.self, forKey: .requiresReview)
        unit = try container.decodeIfPresent(BusinessCatalogUnit.self, forKey: .unit)
        price = try container.decodeFirstMoneyIfPresent(for: [.price, .basePrice, .unitPrice, .localPrice])
        compareAtPrice = try container.decodeFirstMoneyIfPresent(for: [.compareAtPrice])
        cost = try container.decodeFirstMoneyIfPresent(for: [.cost])
        let decodedAttributes = try container.decodeIfPresent([String: String].self, forKey: .attributes) ?? [:]
        brandId = try container.decodeIfPresent(String.self, forKey: .brandId)
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
        unitId = try container.decodeIfPresent(String.self, forKey: .unitId)
        publicDiscoveryStatus = try container.decodeIfPresent(String.self, forKey: .publicDiscoveryStatus)
        productFamilyId = try container.decodeIfPresent(String.self, forKey: .productFamilyId)
        parentProductId = try container.decodeIfPresent(String.self, forKey: .parentProductId)
        variantAttributes = try container.decodeIfPresent([String: String].self, forKey: .variantAttributes) ?? [:]
        identifiers = try container.decodeIfPresent([CatalogIdentifier].self, forKey: .identifiers) ?? []
        alternateCodes = try container.decodeLossyStringArrayIfPresent(forKey: .alternateCodes)
        tags = try container.decodeLossyStringArrayIfPresent(forKey: .tags)
        media = try container.decodeIfPresent([BusinessCatalogMediaAsset].self, forKey: .media) ?? []
        relatedItems = try container.decodeIfPresent([BusinessCatalogRelatedItem].self, forKey: .relatedItems) ?? []
        bundle = try container.decodeIfPresent(BusinessCatalogBundleDefinition.self, forKey: .bundle)
        pricingMetadata = try container.decodeIfPresent(BusinessCatalogMetadataSnapshot.self, forKey: .pricingMetadata) ?? .empty
        commercialMetadata = try container.decodeIfPresent(BusinessCatalogMetadataSnapshot.self, forKey: .commercialMetadata) ?? .empty
        readinessWarnings = try container.decodeLossyStringArrayIfPresent(forKey: .readinessWarnings)
        taxProfileCode = try container.decodeFirstStringIfPresent(for: [.taxProfileCode, .defaultTaxProfileCode, .suggestedTaxProfileCode])
            ?? decodedAttributes.catalogTaxProfileCodeFallback
        taxProfileName = try container.decodeIfPresent(String.self, forKey: .taxProfileName)
        taxProfileId = try container.decodeIfPresent(String.self, forKey: .taxProfileId)
        tracksInventory = try container.decodeIfPresent(Bool.self, forKey: .tracksInventory)
        hasStockProfile = try container.decodeIfPresent(Bool.self, forKey: .hasStockProfile)
        stockStatus = try container.decodeIfPresent(String.self, forKey: .stockStatus)
        availableStock = try container.decodeFirstStringIfPresent(for: [.availableStock, .stock])
        allowNegativeStock = try container.decodeIfPresent(Bool.self, forKey: .allowNegativeStock)
        blockSaleWhenInsufficientStock = try container.decodeIfPresent(
            Bool.self,
            forKey: .blockSaleWhenInsufficientStock
        )
        allowsDecimalQuantity = try container.decodeIfPresent(Bool.self, forKey: .allowsDecimalQuantity)
        attributes = decodedAttributes
    }
}

extension BusinessCatalogItem {
    var saleInventoryStatusLabel: String? {
        guard let tracksInventory else { return nil }
        guard tracksInventory else {
            return isPhysicalProductWithoutInventoryControl
                ? "Inventario no configurado"
                : "Sin control de stock"
        }
        if hasStockProfile == false || normalizedStockStatus == "no_profile" {
            return "Sin perfil de stock"
        }
        if isSaleOutOfStock {
            return "Sin stock"
        }
        if normalizedStockStatus == "low_stock" {
            return availableStock.map { "Stock bajo · \(InventoryPresentationFormatter.number($0)) disponibles" }
                ?? "Stock bajo"
        }
        return availableStock.map { "\(InventoryPresentationFormatter.number($0)) disponibles" }
    }

    var saleStockRiskMessage: String? {
        if isPhysicalProductWithoutInventoryControl {
            return "Este producto no tiene control de inventario configurado. Actívalo en Admin antes de venderlo."
        }
        guard tracksInventory == true else { return nil }
        if hasStockProfile == false || normalizedStockStatus == "no_profile" {
            return saleStockRiskBlocksSale
                ? "Este producto todavía no tiene un perfil de stock. No se puede agregar a la venta."
                : "Este producto todavía no tiene un perfil de stock. El backend validará la política al previsualizar."
        }
        if normalizedStockStatus == "low_stock" {
            return "Stock bajo confirmado por backend. Revisa la cantidad antes de continuar."
        }
        if isSaleOutOfStock {
            return saleStockRiskBlocksSale
                ? "Sin stock disponible. El backend no permite agregar este producto a la venta."
                : "Sin stock disponible confirmado. El backend validará la política al previsualizar la venta."
        }

        return nil
    }

    var saleStockRiskBlocksSale: Bool {
        if isPhysicalProductWithoutInventoryControl { return true }
        guard tracksInventory == true, blockSaleWhenInsufficientStock == true else { return false }
        return hasStockProfile == false || normalizedStockStatus == "no_profile" || isSaleOutOfStock
    }

    private var isPhysicalProductWithoutInventoryControl: Bool {
        type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "product"
            && tracksInventory == false
    }

    private var normalizedStockStatus: String? {
        stockStatus?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var availableStockDecimal: Decimal? {
        availableStock.flatMap {
            Decimal(
                string: $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."),
                locale: Locale(identifier: "en_US_POSIX")
            )
        }
    }

    private var isSaleOutOfStock: Bool {
        normalizedStockStatus.map { ["out_of_stock", "out-of-stock", "sold_out", "empty"].contains($0) } == true
            || availableStockDecimal.map { $0 <= .zero } == true
    }
}

struct CatalogSearchResponse: Decodable, Equatable, Sendable {
    let items: [BusinessCatalogItem]
    let catalogRevision: String?

    init(
        items: [BusinessCatalogItem],
        catalogRevision: String? = nil
    ) {
        self.items = items
        self.catalogRevision = catalogRevision
    }

    fileprivate enum CodingKeys: String, CodingKey {
        case items
        case catalogItems
        case results
        case data
        case catalogRevision
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        items = try container.decodeIfPresent([BusinessCatalogItem].self, forKey: .items)
            ?? container.decodeIfPresent([BusinessCatalogItem].self, forKey: .catalogItems)
            ?? container.decodeIfPresent([BusinessCatalogItem].self, forKey: .results)
            ?? container.decodeIfPresent([BusinessCatalogItem].self, forKey: .data)
            ?? []
        catalogRevision = try container.decodeIfPresent(String.self, forKey: .catalogRevision)
    }
}

private extension String {
    var nilIfBlankForRestaurantAttributes: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Dictionary where Key == String, Value == String {
    var catalogTaxProfileCodeFallback: String? {
        [
            self["taxProfileCode"],
            self["defaultTaxProfileCode"],
            self["suggestedTaxProfileCode"],
            self["productTaxProfileCode"],
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first(where: { !$0.isEmpty })
    }
}

private extension KeyedDecodingContainer where Key == BusinessCatalogItem.CodingKeys {
    func decodeFirstString(for keys: [BusinessCatalogItem.CodingKeys]) throws -> String {
        for key in keys {
            if let value = try decodeFirstStringIfPresent(for: [key]), !value.isEmpty {
                return value
            }
        }

        throw DecodingError.keyNotFound(
            keys.first ?? .id,
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Missing required string value."
            )
        )
    }

    func decodeFirstStringIfPresent(for keys: [BusinessCatalogItem.CodingKeys]) throws -> String? {
        for key in keys {
            if let value = try decodeIfPresent(String.self, forKey: key) {
                return value
            }

            if let intValue = try decodeIfPresent(Int.self, forKey: key) {
                return String(intValue)
            }

            if let doubleValue = try decodeIfPresent(Double.self, forKey: key) {
                return String(doubleValue)
            }
        }

        return nil
    }

    func decodeLossyStringArrayIfPresent(forKey key: BusinessCatalogItem.CodingKeys) throws -> [String] {
        if let values = try decodeIfPresent([String].self, forKey: key) {
            return values
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        if let value = try decodeIfPresent(String.self, forKey: key) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return [] }
            return trimmed
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        if let values = try decodeIfPresent([Int].self, forKey: key) {
            return values.map(String.init)
        }

        if let values = try decodeIfPresent([Double].self, forKey: key) {
            return values.map { String($0) }
        }

        return []
    }

    func decodeFirstMoneyIfPresent(for keys: [BusinessCatalogItem.CodingKeys]) throws -> MoneyAmount? {
        for key in keys {
            if let value = try decodeIfPresent(MoneyAmount.self, forKey: key) {
                return value
            }
        }

        return nil
    }
}

private extension String {
    var nilIfEmptyForCatalog: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
