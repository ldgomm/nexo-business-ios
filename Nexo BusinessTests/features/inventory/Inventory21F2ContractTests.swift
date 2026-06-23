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

    func testAdjustmentRequestEncodesItemIdForCanonicalAdjustmentEndpoint() throws {
        let request = InventoryAdjustmentRequest(
            itemId: "item_1",
            type: .increase,
            quantity: "2",
            reason: "Compra de materia prima",
            note: "Recepción manual"
        )

        let data = try JSONEncoder.nexoDefault.encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["itemId"] as? String, "item_1")
        XCTAssertEqual(object["type"] as? String, "increase")
        XCTAssertEqual(object["quantity"] as? String, "2")
        XCTAssertEqual(object["reason"] as? String, "Compra de materia prima")
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
