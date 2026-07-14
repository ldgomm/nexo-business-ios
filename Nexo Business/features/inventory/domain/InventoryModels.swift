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

    var operationTitle: String {
        switch self {
        case .increase:
            return "Entrada"
        case .decrease:
            return "Salida"
        case .set:
            return "Fijar saldo"
        }
    }

    var defaultReason: String {
        switch self {
        case .increase:
            return "Compra o reposición"
        case .decrease:
            return "Merma o salida operativa"
        case .set:
            return "Corrección de conteo"
        }
    }
}

enum InventoryPresentationFormatter {
    static func number(_ rawValue: String) -> String {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty,
              let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
        else {
            return rawValue
        }
        return NSDecimalNumber(decimal: value).stringValue
    }

    static func dateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_EC")
        formatter.timeZone = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
        let value = InventoryPresentationFormatter.number(quantity)
        guard let unit = displayUnit(for: value) else { return value }
        return "\(value) \(unit)"
    }

    private func displayUnit(for formattedQuantity: String) -> String? {
        let candidate = [unitName, unitCode]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        guard let candidate else { return nil }

        let normalized = candidate.lowercased()
        if ["unit", "units", "unidad", "unidades", "un"].contains(normalized) {
            let decimal = Decimal(
                string: formattedQuantity.replacingOccurrences(of: ",", with: "."),
                locale: Locale(identifier: "en_US_POSIX")
            )
            return decimal == Decimal(1) || decimal == Decimal(-1) ? "unidad" : "unidades"
        }
        return candidate
    }
}

struct InventoryItem: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let branchId: String?
    let catalogItemId: String
    let name: String
    let sku: String?
    let barcode: String?
    let status: String
    let stockStatus: String?
    let trackStock: Bool
    let hasStockProfile: Bool
    let onHand: InventoryQuantity?
    let available: InventoryQuantity
    let reserved: InventoryQuantity?
    let damaged: InventoryQuantity?
    let inTransit: InventoryQuantity?
    let lowStockThreshold: InventoryQuantity?
    let warehouseId: String?
    let allowNegativeStock: Bool?
    let blockSaleWhenInsufficientStock: Bool?
    let averageCost: String?
    let lastCost: String?
    let referenceValue: String?
    let price: MoneyAmount?
    let updatedAt: Date?

    init(
        id: String,
        branchId: String? = nil,
        catalogItemId: String,
        name: String,
        sku: String? = nil,
        barcode: String? = nil,
        status: String = "active",
        stockStatus: String? = nil,
        trackStock: Bool = true,
        hasStockProfile: Bool = true,
        onHand: InventoryQuantity? = nil,
        available: InventoryQuantity,
        reserved: InventoryQuantity? = nil,
        damaged: InventoryQuantity? = nil,
        inTransit: InventoryQuantity? = nil,
        lowStockThreshold: InventoryQuantity? = nil,
        warehouseId: String? = nil,
        allowNegativeStock: Bool? = nil,
        blockSaleWhenInsufficientStock: Bool? = nil,
        averageCost: String? = nil,
        lastCost: String? = nil,
        referenceValue: String? = nil,
        price: MoneyAmount? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.branchId = branchId
        self.catalogItemId = catalogItemId
        self.name = name
        self.sku = sku
        self.barcode = barcode
        self.status = status
        self.stockStatus = stockStatus
        self.trackStock = trackStock
        self.hasStockProfile = hasStockProfile
        self.onHand = onHand
        self.available = available
        self.reserved = reserved
        self.damaged = damaged
        self.inTransit = inTransit
        self.lowStockThreshold = lowStockThreshold
        self.warehouseId = warehouseId
        self.allowNegativeStock = allowNegativeStock
        self.blockSaleWhenInsufficientStock = blockSaleWhenInsufficientStock
        self.averageCost = averageCost
        self.lastCost = lastCost
        self.referenceValue = referenceValue
        self.price = price
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case mongoId = "_id"
        case inventoryItemId
        case branchId
        case catalogItemId
        case itemId
        case name
        case localName
        case displayName
        case sku
        case barcode
        case status
        case stockStatus
        case stockState
        case trackStock
        case tracksInventory
        case tracksStock
        case isTracked
        case hasStockProfile
        case onHand
        case onHandQuantity
        case quantityOnHand
        case available
        case availableQuantity
        case quantityAvailable
        case availableStock
        case quantity
        case reserved
        case reservedQuantity
        case quantityReserved
        case damaged
        case damagedQuantity
        case quantityDamaged
        case inTransit
        case inTransitQuantity
        case quantityInTransit
        case lowStockThreshold
        case threshold
        case stockMin
        case minimumStock
        case reorderPoint
        case warehouseId
        case allowNegativeStock
        case blockSaleWhenInsufficientStock
        case averageCost
        case lastCost
        case referenceValue
        case price
        case basePrice
        case updatedAt
        case unitCode
        case stockUnit
        case unitName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFirstString(for: [.id, .mongoId, .inventoryItemId, .itemId])
        branchId = try container.decodeIfPresent(String.self, forKey: .branchId)
        catalogItemId = try container.decodeFirstStringIfPresent(for: [.catalogItemId, .itemId]) ?? id
        name = try container.decodeFirstStringIfPresent(for: [.name, .localName, .displayName, .sku, .barcode])
            ?? catalogItemId
        sku = try container.decodeIfPresent(String.self, forKey: .sku)
        barcode = try container.decodeIfPresent(String.self, forKey: .barcode)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "active"
        stockStatus = try container.decodeFirstStringIfPresent(for: [.stockStatus, .stockState, .status])
        trackStock = try container.decodeFirstBoolIfPresent(for: [.trackStock, .tracksInventory, .tracksStock, .isTracked]) ?? true
        hasStockProfile = try container.decodeIfPresent(Bool.self, forKey: .hasStockProfile) ?? true
        warehouseId = try container.decodeIfPresent(String.self, forKey: .warehouseId)
        allowNegativeStock = try container.decodeIfPresent(Bool.self, forKey: .allowNegativeStock)
        blockSaleWhenInsufficientStock = try container.decodeIfPresent(Bool.self, forKey: .blockSaleWhenInsufficientStock)
        averageCost = try container.decodeFirstStringIfPresent(for: [.averageCost])
        lastCost = try container.decodeFirstStringIfPresent(for: [.lastCost])
        referenceValue = try container.decodeFirstStringIfPresent(for: [.referenceValue])
        price = try container.decodeFirstMoneyIfPresent(for: [.price, .basePrice])
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)

        let unitCode = try container.decodeFirstStringIfPresent(for: [.unitCode, .stockUnit])
        let unitName = try container.decodeIfPresent(String.self, forKey: .unitName)

        onHand = try container.decodeFirstQuantityIfPresent(
            for: [.onHand, .onHandQuantity, .quantityOnHand],
            unitCode: unitCode,
            unitName: unitName
        )

        available = try container.decodeFirstQuantityIfPresent(
            for: [.available, .availableQuantity, .quantityAvailable, .availableStock, .quantity],
            unitCode: unitCode,
            unitName: unitName
        ) ?? InventoryQuantity(quantity: "0", unitCode: unitCode, unitName: unitName)

        reserved = try container.decodeFirstQuantityIfPresent(
            for: [.reserved, .reservedQuantity, .quantityReserved],
            unitCode: unitCode,
            unitName: unitName
        )

        damaged = try container.decodeFirstQuantityIfPresent(
            for: [.damaged, .damagedQuantity, .quantityDamaged],
            unitCode: unitCode,
            unitName: unitName
        )

        inTransit = try container.decodeFirstQuantityIfPresent(
            for: [.inTransit, .inTransitQuantity, .quantityInTransit],
            unitCode: unitCode,
            unitName: unitName
        )

        lowStockThreshold = try container.decodeFirstQuantityIfPresent(
            for: [.lowStockThreshold, .threshold, .stockMin, .minimumStock, .reorderPoint],
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
    let nextCursor: String?
    let hasMore: Bool

    init(
        items: [InventoryItem],
        catalogRevision: String? = nil,
        totalCount: Int? = nil,
        lowStockCount: Int? = nil,
        outOfStockCount: Int? = nil,
        nextCursor: String? = nil,
        hasMore: Bool = false
    ) {
        self.items = items
        self.catalogRevision = catalogRevision
        self.totalCount = totalCount
        self.lowStockCount = lowStockCount
        self.outOfStockCount = outOfStockCount
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }

    private enum CodingKeys: String, CodingKey {
        case items
        case inventoryItems
        case stock
        case stockItems
        case results
        case data
        case catalogRevision
        case totalCount
        case lowStockCount
        case outOfStockCount
        case nextCursor
        case hasMore
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([InventoryItem].self, forKey: .items)
        ?? container.decodeIfPresent([InventoryItem].self, forKey: .inventoryItems)
        ?? container.decodeIfPresent([InventoryItem].self, forKey: .stock)
        ?? container.decodeIfPresent([InventoryItem].self, forKey: .stockItems)
        ?? container.decodeIfPresent([InventoryItem].self, forKey: .results)
        ?? container.decodeIfPresent([InventoryItem].self, forKey: .data)
        ?? []
        catalogRevision = try container.decodeIfPresent(String.self, forKey: .catalogRevision)
        totalCount = try container.decodeIfPresent(Int.self, forKey: .totalCount)
        lowStockCount = try container.decodeIfPresent(Int.self, forKey: .lowStockCount)
        outOfStockCount = try container.decodeIfPresent(Int.self, forKey: .outOfStockCount)
        nextCursor = try container.decodeIfPresent(String.self, forKey: .nextCursor)
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? (nextCursor != nil)
    }
}

struct InventoryStockItemResponse: Decodable, Equatable, Sendable {
    let item: InventoryItem
    let catalogRevision: String?

    init(item: InventoryItem, catalogRevision: String? = nil) {
        self.item = item
        self.catalogRevision = catalogRevision
    }

    private enum CodingKeys: String, CodingKey {
        case item
        case inventoryItem
        case stockItem
        case stock
        case catalogRevision
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            catalogRevision = try container.decodeIfPresent(String.self, forKey: .catalogRevision)
            if let item = try? container.decode(InventoryItem.self, forKey: .item) {
                self.item = item
                return
            }
            if let item = try? container.decode(InventoryItem.self, forKey: .inventoryItem) {
                self.item = item
                return
            }
            if let item = try? container.decode(InventoryItem.self, forKey: .stockItem) {
                self.item = item
                return
            }
            if let item = try? container.decode(InventoryItem.self, forKey: .stock) {
                self.item = item
                return
            }
        } else {
            catalogRevision = nil
        }

        self.item = try InventoryItem(from: decoder)
    }
}

struct InventoryStockLookupResponse: Decodable, Equatable, Sendable {
    let item: InventoryItem?
    let catalogRevision: String?

    init(item: InventoryItem?, catalogRevision: String? = nil) {
        self.item = item
        self.catalogRevision = catalogRevision
    }

    private enum CodingKeys: String, CodingKey {
        case item
        case inventoryItem
        case stockItem
        case stock
        case catalogRevision
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        catalogRevision = try container.decodeIfPresent(String.self, forKey: .catalogRevision)
        item = try container.decodeIfPresent(InventoryItem.self, forKey: .item)
            ?? container.decodeIfPresent(InventoryItem.self, forKey: .inventoryItem)
            ?? container.decodeIfPresent(InventoryItem.self, forKey: .stockItem)
            ?? container.decodeIfPresent(InventoryItem.self, forKey: .stock)
    }
}

extension InventoryItem {
    var displayName: String {
        let candidate = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty, !candidate.looksLikeInventoryTechnicalIdentifier else {
            return "Producto sin nombre"
        }
        return candidate
    }

    var technicalReference: String? {
        let candidate = catalogItemId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return nil }
        return candidate
    }

    func withCatalogIdentity(name: String, sku: String?, barcode: String?) -> InventoryItem {
        InventoryItem(
            id: id,
            branchId: branchId,
            catalogItemId: catalogItemId,
            name: name,
            sku: sku ?? self.sku,
            barcode: barcode ?? self.barcode,
            status: status,
            stockStatus: stockStatus,
            trackStock: trackStock,
            hasStockProfile: hasStockProfile,
            onHand: onHand,
            available: available,
            reserved: reserved,
            damaged: damaged,
            inTransit: inTransit,
            lowStockThreshold: lowStockThreshold,
            warehouseId: warehouseId,
            allowNegativeStock: allowNegativeStock,
            blockSaleWhenInsufficientStock: blockSaleWhenInsufficientStock,
            averageCost: averageCost,
            lastCost: lastCost,
            referenceValue: referenceValue,
            price: price,
            updatedAt: updatedAt
        )
    }
}

private extension String {
    var looksLikeInventoryTechnicalIdentifier: Bool {
        let normalized = lowercased()
        return normalized.hasPrefix("item_") ||
            normalized.hasPrefix("inv_") ||
            normalized.hasPrefix("stock_") ||
            normalized.hasPrefix("bal_") ||
            normalized.hasPrefix("product_") ||
            normalized.contains("_staging_")
    }
}

struct InventoryMovement: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let branchId: String?
    let inventoryItemId: String
    let catalogItemId: String?
    let type: String
    let quantity: InventoryQuantity
    let quantityDelta: String?
    let signedQuantity: String?
    let quantityBefore: String?
    let quantityAfter: String?
    let balanceBefore: String?
    let balanceAfter: String?
    let previousQuantity: InventoryQuantity?
    let newQuantity: InventoryQuantity?
    let sourceType: String?
    let sourceId: String?
    let sourceLineId: String?
    let warehouseId: String?
    let reasonCode: String?
    let reason: String?
    let reasonText: String?
    let unitCost: String?
    let totalCost: String?
    let createdBy: String?
    let createdAt: Date?

    init(
        id: String,
        branchId: String? = nil,
        inventoryItemId: String,
        catalogItemId: String? = nil,
        type: String,
        quantity: InventoryQuantity,
        quantityDelta: String? = nil,
        signedQuantity: String? = nil,
        quantityBefore: String? = nil,
        quantityAfter: String? = nil,
        balanceBefore: String? = nil,
        balanceAfter: String? = nil,
        previousQuantity: InventoryQuantity? = nil,
        newQuantity: InventoryQuantity? = nil,
        sourceType: String? = nil,
        sourceId: String? = nil,
        sourceLineId: String? = nil,
        warehouseId: String? = nil,
        reasonCode: String? = nil,
        reason: String? = nil,
        reasonText: String? = nil,
        unitCost: String? = nil,
        totalCost: String? = nil,
        createdBy: String? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.branchId = branchId
        self.inventoryItemId = inventoryItemId
        self.catalogItemId = catalogItemId
        self.type = type
        self.quantity = quantity
        self.quantityDelta = quantityDelta
        self.signedQuantity = signedQuantity
        self.quantityBefore = quantityBefore
        self.quantityAfter = quantityAfter
        self.balanceBefore = balanceBefore
        self.balanceAfter = balanceAfter
        self.previousQuantity = previousQuantity
        self.newQuantity = newQuantity
        self.sourceType = sourceType
        self.sourceId = sourceId
        self.sourceLineId = sourceLineId
        self.warehouseId = warehouseId
        self.reasonCode = reasonCode
        self.reason = reason
        self.reasonText = reasonText
        self.unitCost = unitCost
        self.totalCost = totalCost
        self.createdBy = createdBy
        self.createdAt = createdAt
    }

    var quantityChangeDisplayText: String {
        let rawValue = signedQuantity?.nilIfBlank ?? quantityDelta?.nilIfBlank ?? quantity.quantity
        let formatted = InventoryPresentationFormatter.number(rawValue)
        let quantityWithUnit = InventoryQuantity(
            quantity: formatted,
            unitCode: quantity.unitCode,
            unitName: quantity.unitName
        )
        return shouldShowPositiveSign(rawValue)
            ? "+\(quantityWithUnit.displayText)"
            : quantityWithUnit.displayText
    }

    var balanceTransitionDisplayText: String? {
        let before = balanceBefore ?? quantityBefore
        let after = balanceAfter ?? quantityAfter

        if let before, let after {
            return "\(InventoryPresentationFormatter.number(before)) → \(InventoryPresentationFormatter.number(after))"
        }

        if let previousQuantity, let newQuantity {
            return "\(previousQuantity.displayText) → \(newQuantity.displayText)"
        }

        return nil
    }

    var reasonDisplayText: String? {
        if let reasonCode = reasonCode?.nilIfBlank {
            return humanizedMovementReason(reasonCode)
        }
        if let reasonText = reasonText?.nilIfBlank {
            return reasonText
        }
        return reason?.nilIfBlank
    }

    private func shouldShowPositiveSign(_ rawValue: String) -> Bool {
        guard !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("+"),
              let value = Decimal(
                string: rawValue.replacingOccurrences(of: ",", with: "."),
                locale: Locale(identifier: "en_US_POSIX")
              ),
              value > .zero
        else {
            return false
        }
        let normalizedType = type.lowercased()
        return ["increase", "adjustment", "entry", "purchase", "receipt", "sale_reversal", "transfer_in"]
            .contains { normalizedType.contains($0) }
    }

    private func humanizedMovementReason(_ code: String) -> String {
        switch code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "sale_confirmed":
            return "Venta confirmada"
        case "manual_adjustment", "manual":
            return "Ajuste manual"
        case "data_fix":
            return "Corrección de inventario"
        case "physical_count", "count_correction":
            return "Corrección de conteo"
        case "purchase", "restock":
            return "Compra o reposición"
        case "damage", "shrinkage":
            return "Merma o daño"
        default:
            return code
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
        }
    }

    var sourceDisplayText: String? {
        switch (sourceType, sourceId) {
        case let (.some(sourceType), .some(sourceId)) where !sourceType.isEmpty && !sourceId.isEmpty:
            return "\(sourceType) · \(sourceId)"
        case let (.some(sourceType), _) where !sourceType.isEmpty:
            return sourceType
        case let (_, .some(sourceId)) where !sourceId.isEmpty:
            return sourceId
        default:
            return nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case mongoId = "_id"
        case movementId
        case branchId
        case inventoryItemId
        case itemId
        case catalogItemId
        case productId
        case type
        case movementType
        case direction
        case quantity
        case quantityDelta
        case deltaQuantity
        case signedQuantity
        case previousQuantity
        case beforeQuantity
        case quantityBefore
        case balanceBefore
        case newQuantity
        case afterQuantity
        case quantityAfter
        case balanceAfter
        case sourceType
        case sourceId
        case sourceLineId
        case warehouseId
        case reasonCode
        case reason
        case reasonText
        case unitCost
        case totalCost
        case createdBy
        case note
        case notes
        case createdAt
        case occurredAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFirstString(for: [.id, .mongoId, .movementId])
        branchId = try container.decodeIfPresent(String.self, forKey: .branchId)
        inventoryItemId = try container.decodeFirstStringIfPresent(for: [.inventoryItemId, .itemId, .catalogItemId, .productId]) ?? ""
        catalogItemId = try container.decodeFirstStringIfPresent(for: [.catalogItemId, .itemId, .productId])
        type = try container.decodeFirstStringIfPresent(for: [.type, .movementType, .direction]) ?? "adjustment"

        quantityDelta = try container.decodeFirstStringIfPresent(for: [.quantityDelta, .deltaQuantity])
        signedQuantity = try container.decodeFirstStringIfPresent(for: [.signedQuantity])
        quantityBefore = try container.decodeFirstStringIfPresent(for: [.quantityBefore, .beforeQuantity])
        quantityAfter = try container.decodeFirstStringIfPresent(for: [.quantityAfter, .afterQuantity])
        balanceBefore = try container.decodeFirstStringIfPresent(for: [.balanceBefore])
        balanceAfter = try container.decodeFirstStringIfPresent(for: [.balanceAfter])

        let flatQuantity = try container.decodeFirstStringIfPresent(for: [.signedQuantity, .quantityDelta, .deltaQuantity, .quantity])
        quantity = try container.decodeFirstQuantityIfPresent(
            for: [.quantity, .quantityDelta, .deltaQuantity, .signedQuantity],
            unitCode: nil,
            unitName: nil
        ) ?? flatQuantity.map { InventoryQuantity(quantity: $0) } ?? InventoryQuantity(quantity: "0")

        previousQuantity = try container.decodeFirstQuantityIfPresent(
            for: [.previousQuantity, .quantityBefore, .beforeQuantity, .balanceBefore],
            unitCode: nil,
            unitName: nil
        ) ?? (balanceBefore ?? quantityBefore).map { InventoryQuantity(quantity: $0) }

        newQuantity = try container.decodeFirstQuantityIfPresent(
            for: [.newQuantity, .quantityAfter, .afterQuantity, .balanceAfter],
            unitCode: nil,
            unitName: nil
        ) ?? (balanceAfter ?? quantityAfter).map { InventoryQuantity(quantity: $0) }

        sourceType = try container.decodeFirstStringIfPresent(for: [.sourceType])
        sourceId = try container.decodeFirstStringIfPresent(for: [.sourceId])
        sourceLineId = try container.decodeFirstStringIfPresent(for: [.sourceLineId])
        warehouseId = try container.decodeIfPresent(String.self, forKey: .warehouseId)
        reasonCode = try container.decodeFirstStringIfPresent(for: [.reasonCode])

        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        ?? container.decodeIfPresent(String.self, forKey: .note)
        ?? container.decodeIfPresent(String.self, forKey: .notes)
        reasonText = try container.decodeIfPresent(String.self, forKey: .reasonText)
        unitCost = try container.decodeFirstStringIfPresent(for: [.unitCost])
        totalCost = try container.decodeFirstStringIfPresent(for: [.totalCost])
        createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)

        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        ?? container.decodeIfPresent(Date.self, forKey: .occurredAt)
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return nil
        }
        return value
    }
}

struct InventoryMovementsResponse: Decodable, Equatable, Sendable {
    let movements: [InventoryMovement]

    init(movements: [InventoryMovement]) {
        self.movements = movements
    }

    private enum CodingKeys: String, CodingKey {
        case movements
        case inventoryMovements
        case results
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        movements = try container.decodeIfPresent([InventoryMovement].self, forKey: .movements)
        ?? container.decodeIfPresent([InventoryMovement].self, forKey: .inventoryMovements)
        ?? container.decodeIfPresent([InventoryMovement].self, forKey: .results)
        ?? container.decodeIfPresent([InventoryMovement].self, forKey: .data)
        ?? []
    }
}

struct InventoryAdjustmentRequest: Encodable, Equatable, Sendable {
    let branchId: String
    let catalogItemId: String
    let adjustmentType: InventoryAdjustmentType
    let quantity: String
    let reason: String
    let notes: String?

    init(
        branchId: String,
        catalogItemId: String,
        adjustmentType: InventoryAdjustmentType,
        quantity: String,
        reason: String,
        notes: String? = nil
    ) {
        self.branchId = branchId
        self.catalogItemId = catalogItemId
        self.adjustmentType = adjustmentType
        self.quantity = quantity
        self.reason = reason
        self.notes = notes
    }

    var type: InventoryAdjustmentType { adjustmentType }
    var note: String? { notes }

    func withContext(branchId: String, catalogItemId: String) -> InventoryAdjustmentRequest {
        InventoryAdjustmentRequest(
            branchId: branchId,
            catalogItemId: catalogItemId,
            adjustmentType: adjustmentType,
            quantity: quantity,
            reason: reason,
            notes: notes
        )
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

    private enum CodingKeys: String, CodingKey {
        case item
        case inventoryItem
        case stockItem
        case balance
        case movement
        case inventoryMovement
        case stockMovement
        case catalogRevision
        case idempotencyReplayed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        item = try container.decodeIfPresent(InventoryItem.self, forKey: .item)
        ?? container.decodeIfPresent(InventoryItem.self, forKey: .inventoryItem)
        ?? container.decodeIfPresent(InventoryItem.self, forKey: .stockItem)
        ?? container.decode(InventoryItem.self, forKey: .balance)
        movement = try container.decodeIfPresent(InventoryMovement.self, forKey: .movement)
        ?? container.decodeIfPresent(InventoryMovement.self, forKey: .inventoryMovement)
        ?? container.decodeIfPresent(InventoryMovement.self, forKey: .stockMovement)
        catalogRevision = try container.decodeIfPresent(String.self, forKey: .catalogRevision)
        idempotencyReplayed = try container.decodeIfPresent(Bool.self, forKey: .idempotencyReplayed)
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

    func decodeFirstBoolIfPresent(for keys: [Key]) throws -> Bool? {
        for key in keys {
            if let value = try? decodeIfPresent(Bool.self, forKey: key) {
                return value
            }

            if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
                switch stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "true", "yes", "1", "tracked", "enabled":
                    return true
                case "false", "no", "0", "untracked", "disabled":
                    return false
                default:
                    continue
                }
            }

            if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
                return intValue != 0
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
