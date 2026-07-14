//
//  Inventory21F2ContractTests.swift
//  Nexo BusinessTests
//

import XCTest
@testable import Nexo_Business

final class Inventory21F2ContractTests: XCTestCase {
    func testBusinessInventoryRoutesUse21AStockContract() {
        XCTAssertEqual(BusinessInventoryRoutes.stock, "/api/v1/business/inventory/stock")
        XCTAssertEqual(BusinessInventoryRoutes.stockItem(itemId: "item_1"), "/api/v1/business/inventory/stock/item_1")
        XCTAssertEqual(BusinessInventoryRoutes.movements(itemId: "item_1"), "/api/v1/business/inventory/stock/item_1/movements")
        XCTAssertEqual(BusinessInventoryRoutes.adjustments, "/api/v1/business/inventory/adjustments")
    }

    func testAdjustmentRequestEncodesCanonical26RO3AdjustmentContract() throws {
        let request = InventoryAdjustmentRequest(
            branchId: "br_1",
            catalogItemId: "item_1",
            adjustmentType: .increase,
            quantity: "2",
            reason: "Compra de materia prima",
            notes: "Recepción manual"
        )

        let data = try JSONEncoder.nexoDefault.encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["branchId"] as? String, "br_1")
        XCTAssertEqual(object["catalogItemId"] as? String, "item_1")
        XCTAssertEqual(object["adjustmentType"] as? String, "increase")
        XCTAssertEqual(object["quantity"] as? String, "2")
        XCTAssertEqual(object["reason"] as? String, "Compra de materia prima")
        XCTAssertEqual(object["notes"] as? String, "Recepción manual")
        XCTAssertNil(object["itemId"])
        XCTAssertNil(object["type"])
        XCTAssertNil(object["note"])
    }

    func testDecodesStockEnvelopeAndMovementAliases() throws {
        let json = #"""
        {
          "stockItems": [
            {
              "itemId": "item_1",
              "displayName": "Cuy entero",
              "trackStock": true,
              "availableQuantity": { "quantity": "8", "unitName": "unidad" },
              "stockStatus": "active"
            }
          ],
          "catalogRevision": "cat_rev_21a",
          "totalCount": 1
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(InventoryItemsResponse.self, from: json)

        XCTAssertEqual(response.items.first?.id, "item_1")
        XCTAssertEqual(response.items.first?.name, "Cuy entero")
        XCTAssertEqual(response.items.first?.available.quantity, "8")
        XCTAssertEqual(response.catalogRevision, "cat_rev_21a")
    }
}
