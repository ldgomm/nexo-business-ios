//
//  PreviewInventoryData.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum PreviewInventoryData {
    static let items: [InventoryItem] = [
        InventoryItem(
            id: "inv_cuy_entero",
            catalogItemId: "item_cuy_entero",
            name: "Cuy entero",
            sku: "CUY-ENTERO",
            status: "active",
            stockStatus: "active",
            trackStock: true,
            onHand: InventoryQuantity(quantity: "11", unitCode: "unit", unitName: "Unidad"),
            available: InventoryQuantity(quantity: "10", unitCode: "unit", unitName: "Unidad"),
            reserved: InventoryQuantity(quantity: "1", unitCode: "unit", unitName: "Unidad"),
            lowStockThreshold: InventoryQuantity(quantity: "3", unitCode: "unit", unitName: "Unidad"),
            price: MoneyAmount(amount: "24.00"),
            updatedAt: Date()
        ),
        InventoryItem(
            id: "inv_borrego",
            catalogItemId: "item_borrego",
            name: "Borrego asado",
            sku: "BORREGO",
            status: "active",
            stockStatus: "low_stock",
            trackStock: true,
            onHand: InventoryQuantity(quantity: "2", unitCode: "unit", unitName: "Unidad"),
            available: InventoryQuantity(quantity: "2", unitCode: "unit", unitName: "Unidad"),
            reserved: InventoryQuantity(quantity: "0", unitCode: "unit", unitName: "Unidad"),
            lowStockThreshold: InventoryQuantity(quantity: "3", unitCode: "unit", unitName: "Unidad"),
            price: MoneyAmount(amount: "10.00"),
            updatedAt: Date()
        ),
        InventoryItem(
            id: "inv_jugo",
            catalogItemId: "item_jugo",
            name: "Jugo personal",
            sku: "JUGO-PER",
            status: "active",
            stockStatus: "out_of_stock",
            trackStock: true,
            onHand: InventoryQuantity(quantity: "0", unitCode: "unit", unitName: "Unidad"),
            available: InventoryQuantity(quantity: "0", unitCode: "unit", unitName: "Unidad"),
            reserved: InventoryQuantity(quantity: "0", unitCode: "unit", unitName: "Unidad"),
            lowStockThreshold: InventoryQuantity(quantity: "5", unitCode: "unit", unitName: "Unidad"),
            price: MoneyAmount(amount: "1.00"),
            updatedAt: Date()
        )
    ]

    static let movements: [InventoryMovement] = [
        InventoryMovement(
            id: "mov_inv_001",
            inventoryItemId: "inv_cuy_entero",
            type: "increase",
            quantity: InventoryQuantity(quantity: "5", unitCode: "unit", unitName: "Unidad"),
            previousQuantity: InventoryQuantity(quantity: "5", unitCode: "unit", unitName: "Unidad"),
            newQuantity: InventoryQuantity(quantity: "10", unitCode: "unit", unitName: "Unidad"),
            reason: "Compra de reposición",
            createdAt: Date().addingTimeInterval(-3600)
        ),
        InventoryMovement(
            id: "mov_inv_002",
            inventoryItemId: "inv_cuy_entero",
            type: "sale",
            quantity: InventoryQuantity(quantity: "1", unitCode: "unit", unitName: "Unidad"),
            previousQuantity: InventoryQuantity(quantity: "11", unitCode: "unit", unitName: "Unidad"),
            newQuantity: InventoryQuantity(quantity: "10", unitCode: "unit", unitName: "Unidad"),
            reason: "Venta rápida",
            createdAt: Date().addingTimeInterval(-1200)
        )
    ]

    static let itemsResponse = InventoryItemsResponse(
        items: items,
        catalogRevision: PreviewData.businessContext.revisions.catalogRevision,
        totalCount: items.count,
        lowStockCount: items.filter { $0.stockStatus == "low_stock" }.count,
        outOfStockCount: items.filter { $0.stockStatus == "out_of_stock" }.count
    )
}
