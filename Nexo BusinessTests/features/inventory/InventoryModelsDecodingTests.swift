//
//  InventoryModelsDecodingTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class InventoryModelsDecodingTests: XCTestCase {
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
          "item": {
            "id": "inv_1",
            "catalogItemId": "item_1",
            "name": "Cuy entero",
            "status": "active",
            "stockStatus": "active",
            "trackStock": true,
            "available": {
              "quantity": "10",
              "unitCode": "unit",
              "unitName": "Unidad"
            }
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

        XCTAssertEqual(response.item.id, "inv_1")
        XCTAssertEqual(response.item.available.quantity, "10")
        XCTAssertEqual(response.movement?.type, "increase")
        XCTAssertEqual(response.idempotencyReplayed, false)
    }
}
