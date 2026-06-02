//
//  InventoryModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum InventoryItemStockStatus: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case all
    case active
    case lowStock = "low_stock"
    case outOfStock = "out_of_stock"

    var id: String { rawValue }

    var queryValue: String? {
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

    var displayName: String {
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

enum InventoryAdjustmentType: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case increase
    case decrease
    case set

    var id: String { rawValue }

    var displayName: String {
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

struct InventoryQuantity: Codable, Equatable, Sendable {
    let quantity: String
    let unitCode: String?
    let unitName: String?

    init(
        quantity: String,
        unitCode: String? = nil,
        unitName: String? = nil
    ) {
        self.quantity = quantity
        self.unitCode = unitCode
        self.unitName = unitName
    }

    var displayText: String {
        if let unitName, !unitName.isEmpty {
            return "\(quantity) \(unitName)"
        }
        if let unitCode, !unitCode.isEmpty {
            return "\(quantity) \(unitCode)"
        }
        return quantity
    }
}

struct InventoryItem: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let catalogItemId: String
    let name: String
    let sku: String?
    let barcode: String?
    let status: String
    let stockStatus: String?
    let trackStock: Bool
    let available: InventoryQuantity
    let reserved: InventoryQuantity?
    let lowStockThreshold: InventoryQuantity?
    let price: MoneyAmount?
    let updatedAt: Date?

    init(
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

    init(from decoder: Decoder) throws {
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

struct InventoryItemsResponse: Decodable, Equatable, Sendable {
    let items: [InventoryItem]
    let catalogRevision: String?
    let totalCount: Int?
    let lowStockCount: Int?
    let outOfStockCount: Int?

    init(
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

    init(from decoder: Decoder) throws {
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

struct InventoryMovement: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let inventoryItemId: String
    let type: String
    let quantity: InventoryQuantity
    let previousQuantity: InventoryQuantity?
    let newQuantity: InventoryQuantity?
    let reason: String?
    let createdAt: Date?

    init(
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

struct InventoryMovementsResponse: Decodable, Equatable, Sendable {
    let movements: [InventoryMovement]

    init(movements: [InventoryMovement]) {
        self.movements = movements
    }
}

struct InventoryAdjustmentRequest: Encodable, Equatable, Sendable {
    let type: InventoryAdjustmentType
    let quantity: String
    let reason: String
    let note: String?

    init(
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

struct InventoryAdjustmentResponse: Decodable, Equatable, Sendable {
    let item: InventoryItem
    let movement: InventoryMovement?
    let catalogRevision: String?
    let idempotencyReplayed: Bool?

    init(
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
