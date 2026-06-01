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

    func testDecodesCatalogItemUsingValidatedStagingContract() throws {
        let json = #"""
        {
          "items": [
            {
              "id": "item_staging_borrego_asado",
              "organizationId": "org_altos_del_murco_staging",
              "branchId": null,
              "activityId": "act_staging_restaurant",
              "name": "Borrego asado",
              "description": null,
              "sku": null,
              "barcode": null,
              "unit": "unidad",
              "price": {
                "amount": "10.00",
                "currency": "USD"
              },
              "taxProfileId": "taxp_staging_iva_current_full",
              "available": true,
              "status": "active",
              "sortOrder": 3,
              "updatedAt": null
            }
          ],
          "catalogRevision": "catrev_org_altos_del_murco_staging_0"
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(
            CatalogSearchResponse.self,
            from: json
        )

        XCTAssertEqual(response.items[0].id, "item_staging_borrego_asado")
        XCTAssertEqual(response.items[0].unit?.code, "unit")
        XCTAssertEqual(response.items[0].unit?.name, "unidad")
        XCTAssertEqual(response.items[0].unit?.allowsDecimal, false)
        XCTAssertEqual(response.items[0].taxProfileId, "taxp_staging_iva_current_full")
        XCTAssertEqual(response.items[0].price?.amount, "10.00")
    }

}
