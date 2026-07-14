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

    func testDecodesQuickSaleInventoryTruthContract() throws {
        let json = #"""
        {
          "items": [
            {
              "id": "item_staging_medio_cuy",
              "name": "Medio cuy",
              "price": { "amount": "12.00", "currency": "USD" },
              "tracksInventory": true,
              "hasStockProfile": true,
              "stockStatus": "out_of_stock",
              "availableStock": "0",
              "allowNegativeStock": false,
              "blockSaleWhenInsufficientStock": true
            }
          ]
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(CatalogSearchResponse.self, from: json)
        let item = try XCTUnwrap(response.items.first)

        XCTAssertEqual(item.tracksInventory, true)
        XCTAssertEqual(item.hasStockProfile, true)
        XCTAssertEqual(item.stockStatus, "out_of_stock")
        XCTAssertEqual(item.availableStock, "0")
        XCTAssertEqual(item.allowNegativeStock, false)
        XCTAssertEqual(item.blockSaleWhenInsufficientStock, true)
        XCTAssertTrue(item.saleStockRiskBlocksSale)
        XCTAssertEqual(item.saleInventoryStatusLabel, "Sin stock")
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


    func testDecodesMasterCatalogSuggestions() throws {
        let json = #"""
        {
          "templates": [
            {
              "id": "tpl_seed_cuy_entero",
              "globalCatalogId": "restaurant_cuy_entero",
              "canonicalName": "Cuy entero",
              "normalizedName": "cuy entero",
              "type": "PRODUCT",
              "status": "ACTIVE",
              "productFamilyId": "restaurant_cuy",
              "variantAttributes": {},
              "identifiers": [
                {
                  "type": "LOCAL_CODE",
                  "value": "ALT-CUY-ENTERO",
                  "normalizedValue": "alt-cuy-entero",
                  "scope": "PLATFORM",
                  "status": "ACTIVE",
                  "source": "PLATFORM",
                  "isPrimary": true
                }
              ],
              "attributes": {
                "suggestedPrice": "24.00",
                "defaultTaxProfileCode": "iva_current_full",
                "suggestedCategoryCode": "restaurant_main_dishes"
              }
            }
          ]
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(
            CatalogSuggestionSearchResponse.self,
            from: json
        )

        XCTAssertEqual(response.templates.count, 1)
        XCTAssertEqual(response.templates[0].displayName, "Cuy entero")
        XCTAssertEqual(response.templates[0].primaryCode, "ALT-CUY-ENTERO")
        XCTAssertEqual(response.templates[0].suggestedPrice?.amount, "24.00")
        XCTAssertEqual(response.templates[0].suggestedTaxProfileCode, "iva_current_full")
        XCTAssertTrue(response.templates[0].canAdoptFromBusiness)
    }

    func testDecodesAdoptedOrganizationItemUsingLocalPrice() throws {
        let json = #"""
        {
          "id": "ocat_1",
          "organizationId": "org_altos_del_murco_staging",
          "branchId": "branch_1",
          "activityId": "act_restaurant",
          "sourceType": "ADOPTED",
          "templateId": "tpl_seed_cuy_entero",
          "globalCatalogId": "restaurant_cuy_entero",
          "sourceTemplateVersion": "1",
          "localName": "Cuy entero",
          "searchableText": "cuy entero",
          "type": "PRODUCT",
          "status": "ACTIVE",
          "localPrice": {
            "amount": "24.00",
            "currency": "USD"
          },
          "taxProfileId": "taxp_iva_current_full",
          "publicDiscoveryStatus": "PRIVATE",
          "productFamilyId": "restaurant_cuy",
          "variantAttributes": {},
          "identifiers": [],
          "attributes": {}
        }
        """#.data(using: .utf8)!

        let item = try JSONDecoder.nexoDefault.decode(BusinessCatalogItem.self, from: json)

        XCTAssertEqual(item.id, "ocat_1")
        XCTAssertEqual(item.name, "Cuy entero")
        XCTAssertEqual(item.price?.amount, "24.00")
        XCTAssertEqual(item.taxProfileId, "taxp_iva_current_full")
    }

    func testDecodesTaxProfileCodeFromCatalogAttributesFallback() throws {
        let json = #"""
        {
          "id": "ocat_iva_0",
          "localName": "Borrego asado",
          "type": "PRODUCT",
          "status": "ACTIVE",
          "localPrice": {
            "amount": "10.00",
            "currency": "USD"
          },
          "taxProfileId": "taxp_iva_0",
          "attributes": {
            "taxProfileCode": "altos_staging_iva_0"
          }
        }
        """#.data(using: .utf8)!

        let item = try JSONDecoder.nexoDefault.decode(BusinessCatalogItem.self, from: json)

        XCTAssertEqual(item.taxProfileCode, "altos_staging_iva_0")
        XCTAssertEqual(item.taxProfileId, "taxp_iva_0")
    }

}
