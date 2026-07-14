//
//  InventoryModelsDecodingTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class InventoryModelsDecodingTests: XCTestCase {
    func testQuantityPresentationRemovesBackendScaleAndLocalizesUnits() {
        XCTAssertEqual(
            InventoryQuantity(quantity: "45.000000", unitCode: "unit").displayText,
            "45 unidades"
        )
        XCTAssertEqual(
            InventoryQuantity(quantity: "1.000000", unitName: "Unidad").displayText,
            "1 unidad"
        )
        XCTAssertEqual(
            InventoryQuantity(quantity: "1.250000", unitCode: "kg").displayText,
            "1.25 kg"
        )

        let increase = InventoryMovement(
            id: "movement-in",
            inventoryItemId: "item-1",
            type: "increase",
            quantity: InventoryQuantity(quantity: "1.000000", unitCode: "unit"),
            signedQuantity: "1.000000"
        )
        XCTAssertEqual(increase.quantityChangeDisplayText, "+1 unidad")
    }

    func testStockLookupDecodesNullAsMissingProfile() throws {
        let response = try JSONDecoder.nexoDefault.decode(
            InventoryStockLookupResponse.self,
            from: Data(#"{"stock":null,"catalogRevision":"26R"}"#.utf8)
        )

        XCTAssertNil(response.item)
        XCTAssertEqual(response.catalogRevision, "26R")
    }

    func testStockLookupDecodesBackendStockEnvelope() throws {
        let response = try JSONDecoder.nexoDefault.decode(
            InventoryStockLookupResponse.self,
            from: Data(#"{"stock":{"id":"stock-1","catalogItemId":"product-1","available":"4","hasStockProfile":true}}"#.utf8)
        )

        XCTAssertEqual(response.item?.catalogItemId, "product-1")
        XCTAssertEqual(response.item?.available.quantity, "4")
    }

    func testDecodesInventoryItemsResponseWithFlexibleKeys() throws {
        let json = #"""
        {
          "inventoryItems": [
            {
              "_id": "inv_1",
              "catalogItemId": "item_1",
              "localName": "Cuy entero",
              "sku": "CUY-ENTERO",
              "status": "active",
              "stockStatus": "low_stock",
              "trackStock": true,
              "availableQuantity": "2",
              "reservedQuantity": "1",
              "lowStockThreshold": "3",
              "unitCode": "unit",
              "unitName": "Unidad",
              "updatedAt": "2026-05-29T12:00:00Z"
            }
          ],
          "catalogRevision": "cat_rev_001",
          "totalCount": 1,
          "lowStockCount": 1,
          "outOfStockCount": 0
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(
            InventoryItemsResponse.self,
            from: json
        )

        XCTAssertEqual(response.items.count, 1)
        XCTAssertEqual(response.items[0].id, "inv_1")
        XCTAssertEqual(response.items[0].name, "Cuy entero")
        XCTAssertEqual(response.items[0].available.quantity, "2")
        XCTAssertEqual(response.items[0].available.unitName, "Unidad")
        XCTAssertEqual(response.catalogRevision, "cat_rev_001")
        XCTAssertEqual(response.lowStockCount, 1)
    }

    func testDecodesAdjustmentResponse() throws {
        let json = #"""
        {
          "balance": {
            "id": "bal_1",
            "branchId": "br_1",
            "itemId": "item_1",
            "catalogItemId": "item_1",
            "status": "active",
            "tracksInventory": true,
            "quantityOnHand": "10",
            "quantityReserved": "0",
            "quantityAvailable": "10",
            "quantityDamaged": "0",
            "quantityInTransit": "0",
            "stockUnit": "unit",
            "stockMin": "2",
            "allowNegativeStock": false,
            "blockSaleWhenInsufficientStock": true,
            "warehouseId": "wh_1",
            "averageCost": "4.25",
            "lastCost": "4.50",
            "referenceValue": "42.50",
            "updatedAt": "2026-07-12T12:00:00Z"
          },
          "movement": {
            "id": "mov_1",
            "inventoryItemId": "inv_1",
            "type": "increase",
            "quantity": {
              "quantity": "5",
              "unitCode": "unit",
              "unitName": "Unidad"
            },
            "reason": "Reposición"
          },
          "idempotencyReplayed": false
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(
            InventoryAdjustmentResponse.self,
            from: json
        )

        XCTAssertEqual(response.item.id, "bal_1")
        XCTAssertEqual(response.item.name, "item_1")
        XCTAssertEqual(response.item.displayName, "Producto sin nombre")
        XCTAssertEqual(response.item.catalogItemId, "item_1")
        XCTAssertEqual(response.item.available.quantity, "10")
        XCTAssertEqual(response.item.warehouseId, "wh_1")
        XCTAssertEqual(response.item.averageCost, "4.25")
        XCTAssertEqual(response.item.blockSaleWhenInsufficientStock, true)
        XCTAssertEqual(response.movement?.type, "increase")
        XCTAssertEqual(response.idempotencyReplayed, false)
    }

    func testDecodesBackendStockDetailEnvelope() throws {
        let json = #"""
        {
          "stock": {
            "id": "bal_1",
            "branchId": "br_1",
            "itemId": "item_1",
            "catalogItemId": "item_1",
            "quantityOnHand": "7",
            "quantityReserved": "2",
            "quantityAvailable": "5",
            "stockUnit": "unit",
            "stockMin": "3",
            "status": "low_stock",
            "tracksInventory": true,
            "allowNegativeStock": false,
            "blockSaleWhenInsufficientStock": true,
            "lastMovementAt": null,
            "updatedAt": "2026-07-12T12:00:00Z",
            "warehouseId": "wh_1",
            "quantityDamaged": "1",
            "quantityInTransit": "4",
            "averageCost": null,
            "lastCost": null,
            "referenceValue": null
          }
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(InventoryStockItemResponse.self, from: json)

        XCTAssertEqual(response.item.id, "bal_1")
        XCTAssertEqual(response.item.catalogItemId, "item_1")
        XCTAssertEqual(response.item.name, "item_1")
        XCTAssertEqual(response.item.displayName, "Producto sin nombre")
        XCTAssertEqual(response.item.onHand?.quantity, "7")
        XCTAssertEqual(response.item.available.quantity, "5")
        XCTAssertEqual(response.item.reserved?.quantity, "2")
        XCTAssertEqual(response.item.damaged?.quantity, "1")
        XCTAssertEqual(response.item.inTransit?.quantity, "4")
        XCTAssertEqual(response.item.stockStatus, "low_stock")
    }

    func testEncodesExactBackendAdjustmentRequestKeys() throws {
        let request = InventoryAdjustmentRequest(
            branchId: "br_1",
            catalogItemId: "item_1",
            adjustmentType: .increase,
            quantity: "2",
            reason: "Reposición",
            notes: "Ingreso controlado"
        )

        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["branchId"] as? String, "br_1")
        XCTAssertEqual(object["catalogItemId"] as? String, "item_1")
        XCTAssertEqual(object["adjustmentType"] as? String, "increase")
        XCTAssertEqual(object["notes"] as? String, "Ingreso controlado")
        XCTAssertNil(object["type"])
        XCTAssertNil(object["note"])
        XCTAssertNil(object["itemId"])
    }

    func testDecodesBackendInventoryMovementHistoryContract() throws {
        let json = #"""
        {
          "movements": [
            {
              "id": "stmov_1",
              "branchId": "br_staging_matriz",
              "itemId": "item_staging_jugo_personal",
              "catalogItemId": "item_staging_jugo_personal",
              "movementType": "sale",
              "type": "sale",
              "direction": "out",
              "quantity": "1.000000",
              "quantityDelta": "-1.000000",
              "quantityBefore": "45.000000",
              "quantityAfter": "44.000000",
              "signedQuantity": "-1.000000",
              "balanceBefore": "45.000000",
              "balanceAfter": "44.000000",
              "sourceType": "sale",
              "sourceId": "sale_123",
              "sourceLineId": "sitem_123",
              "reason": "Venta confirmada sale_123",
              "reasonCode": "sale_confirmed",
              "occurredAt": "2026-07-08T13:32:43.349Z"
            }
          ]
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(
            InventoryMovementsResponse.self,
            from: json
        )

        let movement = try XCTUnwrap(response.movements.first)
        XCTAssertEqual(movement.id, "stmov_1")
        XCTAssertEqual(movement.inventoryItemId, "item_staging_jugo_personal")
        XCTAssertEqual(movement.type, "sale")
        XCTAssertEqual(movement.quantityDelta, "-1.000000")
        XCTAssertEqual(movement.signedQuantity, "-1.000000")
        XCTAssertEqual(movement.quantityBefore, "45.000000")
        XCTAssertEqual(movement.quantityAfter, "44.000000")
        XCTAssertEqual(movement.balanceBefore, "45.000000")
        XCTAssertEqual(movement.balanceAfter, "44.000000")
        XCTAssertEqual(movement.sourceType, "sale")
        XCTAssertEqual(movement.sourceId, "sale_123")
        XCTAssertEqual(movement.sourceLineId, "sitem_123")
        XCTAssertEqual(movement.catalogItemId, "item_staging_jugo_personal")
        XCTAssertEqual(movement.reasonCode, "sale_confirmed")
        XCTAssertEqual(movement.quantityChangeDisplayText, "-1")
        XCTAssertEqual(movement.balanceTransitionDisplayText, "45 → 44")
        XCTAssertEqual(movement.reasonDisplayText, "Venta confirmada")
        XCTAssertEqual(movement.sourceDisplayText, "sale · sale_123")
    }

    func testUntrackedBalanceNeverPresentsAsAvailable() {
        let item = InventoryItem(
            id: "item_untracked",
            catalogItemId: "item_untracked",
            name: "Producto sin control",
            stockStatus: "available",
            trackStock: false,
            hasStockProfile: true,
            available: InventoryQuantity(quantity: "0", unitCode: "unit")
        )

        XCTAssertEqual(InventoryStatusPresentation.displayName(item), "Sin control stock")
    }

    func testTrackedZeroBalancePresentsAsOutOfStockDefensively() {
        let item = InventoryItem(
            id: "item_zero",
            catalogItemId: "item_zero",
            name: "Producto sin stock",
            stockStatus: "available",
            trackStock: true,
            hasStockProfile: true,
            available: InventoryQuantity(quantity: "0", unitCode: "unit")
        )

        XCTAssertEqual(InventoryStatusPresentation.displayName(item), "Sin stock")
    }

}
