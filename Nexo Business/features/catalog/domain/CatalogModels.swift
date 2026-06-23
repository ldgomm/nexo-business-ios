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
    let sku: String?
    let barcode: String?
    let type: String?
    let status: String?
    let localStatus: String?
    let masterStatus: String?
    let effectiveStatus: String?
    let availabilityLabel: String?
    let source: String?
    let masterCatalogItemId: String?
    let canActivate: Bool?
    let canDeactivate: Bool?
    let unit: BusinessCatalogUnit?
    let price: MoneyAmount?
    let taxProfileCode: String?
    let taxProfileName: String?
    let taxProfileId: String?
    let availableStock: String?
    let allowsDecimalQuantity: Bool?

    init(
        id: String,
        name: String,
        itemDescription: String? = nil,
        sku: String? = nil,
        barcode: String? = nil,
        type: String? = nil,
        status: String? = nil,
        localStatus: String? = nil,
        masterStatus: String? = nil,
        effectiveStatus: String? = nil,
        availabilityLabel: String? = nil,
        source: String? = nil,
        masterCatalogItemId: String? = nil,
        canActivate: Bool? = nil,
        canDeactivate: Bool? = nil,
        unit: BusinessCatalogUnit? = nil,
        price: MoneyAmount? = nil,
        taxProfileCode: String? = nil,
        taxProfileName: String? = nil,
        taxProfileId: String? = nil,
        availableStock: String? = nil,
        allowsDecimalQuantity: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.itemDescription = itemDescription
        self.sku = sku
        self.barcode = barcode
        self.type = type
        self.status = status
        self.localStatus = localStatus
        self.masterStatus = masterStatus
        self.effectiveStatus = effectiveStatus
        self.availabilityLabel = availabilityLabel
        self.source = source
        self.masterCatalogItemId = masterCatalogItemId
        self.canActivate = canActivate
        self.canDeactivate = canDeactivate
        self.unit = unit
        self.price = price
        self.taxProfileCode = taxProfileCode
        self.taxProfileName = taxProfileName
        self.taxProfileId = taxProfileId
        self.availableStock = availableStock
        self.allowsDecimalQuantity = allowsDecimalQuantity
    }

    fileprivate enum CodingKeys: String, CodingKey {
        case id
        case mongoId = "_id"
        case name
        case localName
        case displayName
        case description
        case localDescription
        case sku
        case barcode
        case type
        case status
        case localStatus
        case masterStatus
        case effectiveStatus
        case availabilityLabel
        case source
        case sourceType
        case masterCatalogItemId
        case templateId
        case canActivate
        case canDeactivate
        case unit
        case price
        case basePrice
        case unitPrice
        case localPrice
        case taxProfileCode
        case taxProfileName
        case taxProfileId
        case availableStock
        case stock
        case allowsDecimalQuantity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFirstString(for: [.id, .mongoId])
        name = try container.decodeFirstString(for: [.name, .localName, .displayName])
        itemDescription = try container.decodeFirstStringIfPresent(for: [.description, .localDescription])
        sku = try container.decodeIfPresent(String.self, forKey: .sku)
        barcode = try container.decodeIfPresent(String.self, forKey: .barcode)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        localStatus = try container.decodeIfPresent(String.self, forKey: .localStatus)
        masterStatus = try container.decodeIfPresent(String.self, forKey: .masterStatus)
        effectiveStatus = try container.decodeIfPresent(String.self, forKey: .effectiveStatus)
        availabilityLabel = try container.decodeIfPresent(String.self, forKey: .availabilityLabel)
        source = try container.decodeFirstStringIfPresent(for: [.source, .sourceType])
        masterCatalogItemId = try container.decodeFirstStringIfPresent(for: [.masterCatalogItemId, .templateId])
        canActivate = try container.decodeIfPresent(Bool.self, forKey: .canActivate)
        canDeactivate = try container.decodeIfPresent(Bool.self, forKey: .canDeactivate)
        unit = try container.decodeIfPresent(BusinessCatalogUnit.self, forKey: .unit)
        price = try container.decodeFirstMoneyIfPresent(for: [.price, .basePrice, .unitPrice, .localPrice])
        taxProfileCode = try container.decodeIfPresent(String.self, forKey: .taxProfileCode)
        taxProfileName = try container.decodeIfPresent(String.self, forKey: .taxProfileName)
        taxProfileId = try container.decodeIfPresent(String.self, forKey: .taxProfileId)
        availableStock = try container.decodeFirstStringIfPresent(for: [.availableStock, .stock])
        allowsDecimalQuantity = try container.decodeIfPresent(Bool.self, forKey: .allowsDecimalQuantity)
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
