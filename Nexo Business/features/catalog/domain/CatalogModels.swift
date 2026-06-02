//
//  CatalogModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public struct BusinessCatalogUnit: Decodable, Equatable, Sendable {
    public let code: String?
    public let name: String?
    public let allowsDecimal: Bool?

    public init(
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

    public init(from decoder: Decoder) throws {
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

public struct BusinessCatalogItem: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let itemDescription: String?
    public let sku: String?
    public let barcode: String?
    public let type: String?
    public let status: String?
    public let unit: BusinessCatalogUnit?
    public let price: MoneyAmount?
    public let taxProfileCode: String?
    public let taxProfileName: String?
    public let taxProfileId: String?
    public let availableStock: String?
    public let allowsDecimalQuantity: Bool?

    public init(
        id: String,
        name: String,
        itemDescription: String? = nil,
        sku: String? = nil,
        barcode: String? = nil,
        type: String? = nil,
        status: String? = nil,
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
        case unit
        case price
        case basePrice
        case unitPrice
        case taxProfileCode
        case taxProfileName
        case taxProfileId
        case availableStock
        case stock
        case allowsDecimalQuantity
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFirstString(for: [.id, .mongoId])
        name = try container.decodeFirstString(for: [.name, .localName, .displayName])
        itemDescription = try container.decodeFirstStringIfPresent(for: [.description, .localDescription])
        sku = try container.decodeIfPresent(String.self, forKey: .sku)
        barcode = try container.decodeIfPresent(String.self, forKey: .barcode)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        unit = try container.decodeIfPresent(BusinessCatalogUnit.self, forKey: .unit)
        price = try container.decodeFirstMoneyIfPresent(for: [.price, .basePrice, .unitPrice])
        taxProfileCode = try container.decodeIfPresent(String.self, forKey: .taxProfileCode)
        taxProfileName = try container.decodeIfPresent(String.self, forKey: .taxProfileName)
        taxProfileId = try container.decodeIfPresent(String.self, forKey: .taxProfileId)
        availableStock = try container.decodeFirstStringIfPresent(for: [.availableStock, .stock])
        allowsDecimalQuantity = try container.decodeIfPresent(Bool.self, forKey: .allowsDecimalQuantity)
    }
}

public struct CatalogSearchResponse: Decodable, Equatable, Sendable {
    public let items: [BusinessCatalogItem]
    public let catalogRevision: String?

    public init(
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

    public init(from decoder: Decoder) throws {
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
