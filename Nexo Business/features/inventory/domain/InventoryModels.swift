//
//  InventoryModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public enum InventoryItemStockStatus: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case all
    case active
    case lowStock = "low_stock"
    case outOfStock = "out_of_stock"

    public var id: String { rawValue }

    public var queryValue: String? {
        switch self {
        case .all:
            return nil
        case .active:
            return "active"
        case .lowStock:
            return "low_stock"
        case .outOfStock:
            return "out_of_stock"
        }
    }

    public var displayName: String {
        switch self {
        case .all:
            return "Todos"
        case .active:
            return "Activos"
        case .lowStock:
            return "Stock bajo"
        case .outOfStock:
            return "Sin stock"
        }
    }
}

public enum InventoryAdjustmentType: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case increase
    case decrease
    case set

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .increase:
            return "Aumentar"
        case .decrease:
            return "Disminuir"
        case .set:
            return "Fijar stock"
        }
    }
}

public struct InventoryQuantity: Codable, Equatable, Sendable {
    public let quantity: String
    public let unitCode: String?
    public let unitName: String?

    public init(
        quantity: String,
        unitCode: String? = nil,
        unitName: String? = nil
    ) {
        self.quantity = quantity
        self.unitCode = unitCode
        self.unitName = unitName
    }

    public var displayText: String {
        if let unitName, !unitName.isEmpty {
            return "\(quantity) \(unitName)"
        }
        if let unitCode, !unitCode.isEmpty {
            return "\(quantity) \(unitCode)"
        }
        return quantity
    }
}

public struct InventoryItem: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let catalogItemId: String
    public let name: String
    public let sku: String?
    public let barcode: String?
    public let status: String
    public let stockStatus: String?
    public let trackStock: Bool
    public let available: InventoryQuantity
    public let reserved: InventoryQuantity?
    public let lowStockThreshold: InventoryQuantity?
    public let price: MoneyAmount?
    public let updatedAt: Date?

    public init(
        id: String,
        catalogItemId: String,
        name: String,
        sku: String? = nil,
        barcode: String? = nil,
        status: String = "active",
        stockStatus: String? = nil,
        trackStock: Bool = true,
        available: InventoryQuantity,
        reserved: InventoryQuantity? = nil,
        lowStockThreshold: InventoryQuantity? = nil,
        price: MoneyAmount? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.catalogItemId = catalogItemId
        self.name = name
        self.sku = sku
        self.barcode = barcode
        self.status = status
        self.stockStatus = stockStatus
        self.trackStock = trackStock
        self.available = available
        self.reserved = reserved
        self.lowStockThreshold = lowStockThreshold
        self.price = price
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case mongoId = "_id"
        case inventoryItemId
        case catalogItemId
        case itemId
        case name
        case localName
        case displayName
        case sku
        case barcode
        case status
        case stockStatus
        case trackStock
        case available
        case availableQuantity
        case quantity
        case reserved
        case reservedQuantity
        case lowStockThreshold
        case threshold
        case price
        case basePrice
        case updatedAt
        case unitCode
        case unitName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFirstString(for: [.id, .mongoId, .inventoryItemId])
        catalogItemId = try container.decodeFirstStringIfPresent(for: [.catalogItemId, .itemId]) ?? id
        name = try container.decodeFirstString(for: [.name, .localName, .displayName])
        sku = try container.decodeIfPresent(String.self, forKey: .sku)
        barcode = try container.decodeIfPresent(String.self, forKey: .barcode)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "active"
        stockStatus = try container.decodeIfPresent(String.self, forKey: .stockStatus)
        trackStock = try container.decodeIfPresent(Bool.self, forKey: .trackStock) ?? true
        price = try container.decodeFirstMoneyIfPresent(for: [.price, .basePrice])
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)

        let unitCode = try container.decodeIfPresent(String.self, forKey: .unitCode)
        let unitName = try container.decodeIfPresent(String.self, forKey: .unitName)

        available = try container.decodeFirstQuantityIfPresent(
            for: [.available, .availableQuantity, .quantity],
            unitCode: unitCode,
            unitName: unitName
        ) ?? InventoryQuantity(quantity: "0", unitCode: unitCode, unitName: unitName)

        reserved = try container.decodeFirstQuantityIfPresent(
            for: [.reserved, .reservedQuantity],
            unitCode: unitCode,
            unitName: unitName
        )

        lowStockThreshold = try container.decodeFirstQuantityIfPresent(
            for: [.lowStockThreshold, .threshold],
            unitCode: unitCode,
            unitName: unitName
        )
    }
}

public struct InventoryItemsResponse: Decodable, Equatable, Sendable {
    public let items: [InventoryItem]
    public let catalogRevision: String?
    public let totalCount: Int?
    public let lowStockCount: Int?
    public let outOfStockCount: Int?

    public init(
        items: [InventoryItem],
        catalogRevision: String? = nil,
        totalCount: Int? = nil,
        lowStockCount: Int? = nil,
        outOfStockCount: Int? = nil
    ) {
        self.items = items
        self.catalogRevision = catalogRevision
        self.totalCount = totalCount
        self.lowStockCount = lowStockCount
        self.outOfStockCount = outOfStockCount
    }

    private enum CodingKeys: String, CodingKey {
        case items
        case inventoryItems
        case results
        case data
        case catalogRevision
        case totalCount
        case lowStockCount
        case outOfStockCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([InventoryItem].self, forKey: .items)
            ?? container.decodeIfPresent([InventoryItem].self, forKey: .inventoryItems)
            ?? container.decodeIfPresent([InventoryItem].self, forKey: .results)
            ?? container.decodeIfPresent([InventoryItem].self, forKey: .data)
            ?? []
        catalogRevision = try container.decodeIfPresent(String.self, forKey: .catalogRevision)
        totalCount = try container.decodeIfPresent(Int.self, forKey: .totalCount)
        lowStockCount = try container.decodeIfPresent(Int.self, forKey: .lowStockCount)
        outOfStockCount = try container.decodeIfPresent(Int.self, forKey: .outOfStockCount)
    }
}

public struct InventoryMovement: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let inventoryItemId: String
    public let type: String
    public let quantity: InventoryQuantity
    public let previousQuantity: InventoryQuantity?
    public let newQuantity: InventoryQuantity?
    public let reason: String?
    public let createdAt: Date?

    public init(
        id: String,
        inventoryItemId: String,
        type: String,
        quantity: InventoryQuantity,
        previousQuantity: InventoryQuantity? = nil,
        newQuantity: InventoryQuantity? = nil,
        reason: String? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.inventoryItemId = inventoryItemId
        self.type = type
        self.quantity = quantity
        self.previousQuantity = previousQuantity
        self.newQuantity = newQuantity
        self.reason = reason
        self.createdAt = createdAt
    }
}

public struct InventoryMovementsResponse: Decodable, Equatable, Sendable {
    public let movements: [InventoryMovement]

    public init(movements: [InventoryMovement]) {
        self.movements = movements
    }
}

public struct InventoryAdjustmentRequest: Encodable, Equatable, Sendable {
    public let type: InventoryAdjustmentType
    public let quantity: String
    public let reason: String
    public let note: String?

    public init(
        type: InventoryAdjustmentType,
        quantity: String,
        reason: String,
        note: String? = nil
    ) {
        self.type = type
        self.quantity = quantity
        self.reason = reason
        self.note = note
    }
}

public struct InventoryAdjustmentResponse: Decodable, Equatable, Sendable {
    public let item: InventoryItem
    public let movement: InventoryMovement?
    public let catalogRevision: String?
    public let idempotencyReplayed: Bool?

    public init(
        item: InventoryItem,
        movement: InventoryMovement? = nil,
        catalogRevision: String? = nil,
        idempotencyReplayed: Bool? = nil
    ) {
        self.item = item
        self.movement = movement
        self.catalogRevision = catalogRevision
        self.idempotencyReplayed = idempotencyReplayed
    }
}

private extension KeyedDecodingContainer {
    func decodeFirstString(for keys: [Key]) throws -> String {
        for key in keys {
            if let value = try decodeFirstStringIfPresent(for: [key]), !value.isEmpty {
                return value
            }
        }

        throw DecodingError.keyNotFound(
            keys[0],
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Expected one of keys: \(keys.map(\.stringValue).joined(separator: ", "))"
            )
        )
    }

    func decodeFirstStringIfPresent(for keys: [Key]) throws -> String? {
        for key in keys {
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value
            }

            if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
                return String(intValue)
            }

            if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
                return String(doubleValue)
            }
        }

        return nil
    }

    func decodeFirstMoneyIfPresent(for keys: [Key]) throws -> MoneyAmount? {
        for key in keys {
            if let value = try? decodeIfPresent(MoneyAmount.self, forKey: key) {
                return value
            }
        }

        return nil
    }

    func decodeFirstQuantityIfPresent(
        for keys: [Key],
        unitCode: String?,
        unitName: String?
    ) throws -> InventoryQuantity? {
        for key in keys {
            if let value = try? decodeIfPresent(InventoryQuantity.self, forKey: key) {
                return value
            }

            if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
                return InventoryQuantity(
                    quantity: stringValue,
                    unitCode: unitCode,
                    unitName: unitName
                )
            }

            if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
                return InventoryQuantity(
                    quantity: String(intValue),
                    unitCode: unitCode,
                    unitName: unitName
                )
            }

            if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
                return InventoryQuantity(
                    quantity: String(doubleValue),
                    unitCode: unitCode,
                    unitName: unitName
                )
            }
        }

        return nil
    }
}
