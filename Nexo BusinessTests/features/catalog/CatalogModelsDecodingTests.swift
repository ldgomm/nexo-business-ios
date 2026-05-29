//
//  CatalogModelsDecodingTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class CatalogModelsDecodingTests: XCTestCase {
    func testDecodesCatalogItemsUsingLocalNameAndBasePrice() throws {
        let json = #"""
        {
          "items": [
            {
              "_id": "item_1",
              "localName": "Cuy entero",
              "localDescription": "Plato principal",
              "sku": "CUY-001",
              "type": "product",
              "status": "active",
              "unit": {
                "code": "unit",
                "name": "Unidad",
                "allowsDecimal": false
              },
              "basePrice": {
                "amount": "24.00",
                "currency": "USD"
              },
              "taxProfileCode": "iva_current_full",
              "availableStock": "10"
            }
          ],
          "catalogRevision": "cat_rev_001"
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(
            CatalogSearchResponse.self,
            from: json
        )

        XCTAssertEqual(response.items.count, 1)
        XCTAssertEqual(response.items[0].id, "item_1")
        XCTAssertEqual(response.items[0].name, "Cuy entero")
        XCTAssertEqual(response.items[0].price?.amount, "24.00")
        XCTAssertEqual(response.catalogRevision, "cat_rev_001")
    }

    func testDecodesCatalogItemsFromCatalogItemsKey() throws {
        let json = #"""
        {
          "catalogItems": [
            {
              "id": "item_2",
              "name": "Borrego",
              "price": {
                "amount": "10.00",
                "currency": "USD"
              }
            }
          ]
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(
            CatalogSearchResponse.self,
            from: json
        )

        XCTAssertEqual(response.items[0].id, "item_2")
        XCTAssertEqual(response.items[0].name, "Borrego")
    }
}
