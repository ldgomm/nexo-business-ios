//
//  BusinessVerticalContext22CTests.swift
//  Nexo BusinessTests
//
//  Created for Nexo 22C.
//

import XCTest
@testable import Nexo_Business

final class BusinessVerticalContext22CTests: XCTestCase {
    func testDecodesBusinessVerticalContextFromBackend22AShape() throws {
        let json = #"""
        {
          "user": { "id": "usr_1", "displayName": "Operador", "email": "op@nexo.test" },
          "organization": {
            "id": "org_altos_del_murco_staging",
            "commercialName": "Altos del Murco",
            "legalName": "Altos del Murco",
            "taxId": "1790000000001",
            "countryCode": "EC"
          },
          "branches": [
            { "id": "br_staging_matriz", "name": "Matriz", "code": "001", "status": "active" }
          ],
          "activeBranchId": "br_staging_matriz",
          "activities": [
            {
              "id": "act_staging_restaurant",
              "activityType": "restaurant",
              "workflowMode": "quick_sale",
              "status": "active"
            }
          ],
          "activeModules": ["core.sales", "core.cash", "core.catalog"],
          "effectivePermissions": ["sales.create", "cash.view", "customers.view"],
          "revisions": {
            "catalogRevision": "catrev_1",
            "taxConfigurationRevision": "taxrev_1"
          },
          "readiness": {
            "status": "ready",
            "score": 100,
            "blockers": [],
            "warnings": []
          },
          "verticals": {
            "activeVerticals": [
              {
                "code": "restaurant",
                "displayName": "Restaurante v1",
                "packageVersion": "1.0.0",
                "status": "ACTIVE",
                "capabilities": [
                  "restaurant.menu_attributes",
                  "restaurant.service_type",
                  "restaurant.event_service"
                ],
                "workModes": ["quick_sale", "restaurant_counter", "table_service", "event_service"],
                "surfaces": [
                  "business.home.restaurant",
                  "business.sale.service_type_picker",
                  "business.catalog.restaurant_attributes"
                ],
                "defaultWorkMode": "quick_sale"
              }
            ],
            "defaultVerticalCode": "restaurant",
            "workMode": "quick_sale",
            "surfaces": [
              "business.home.restaurant",
              "business.sale.service_type_picker",
              "business.catalog.restaurant_attributes"
            ],
            "capabilities": [
              "restaurant.menu_attributes",
              "restaurant.service_type",
              "restaurant.event_service"
            ],
            "readiness": [
              { "code": "catalog_has_items", "status": "PASS", "message": "Catálogo tiene 12 items.", "details": { "catalogItems": "12" } },
              { "code": "roles_ready", "status": "WARN", "message": "Revisar roles humanos.", "details": {} }
            ]
          }
        }
        """#.data(using: .utf8)!

        let context = try JSONDecoder.nexoDefault.decode(BusinessContextResponse.self, from: json)

        XCTAssertTrue(context.verticals.hasRestaurant)
        XCTAssertEqual(context.verticals.defaultVerticalCode, "restaurant")
        XCTAssertEqual(context.verticals.workMode, "quick_sale")
        XCTAssertEqual(context.verticals.restaurant?.displayName, "Restaurante v1")
        XCTAssertTrue(context.verticals.hasCapability("restaurant.service_type"))
        XCTAssertTrue(context.verticals.hasSurface("business.home.restaurant"))
        XCTAssertEqual(context.verticals.readiness.count, 2)
        XCTAssertEqual(context.verticals.readiness.last?.normalizedStatus, "WARN")
        XCTAssertTrue(context.verticals.foreignVerticalCodes.isEmpty)
    }

    func testMissingVerticalsIsBackwardsCompatible() throws {
        let json = #"""
        {
          "user": { "id": "usr_1", "displayName": "Operador", "email": "op@nexo.test" },
          "organization": {
            "id": "org_1",
            "commercialName": "Negocio",
            "legalName": "Negocio",
            "taxId": "1790000000001",
            "countryCode": "EC"
          },
          "branches": [],
          "activities": [],
          "activeModules": [],
          "effectivePermissions": [],
          "catalogRevision": "catrev_1",
          "taxConfigurationRevision": "taxrev_1",
          "moduleReadiness": []
        }
        """#.data(using: .utf8)!

        let context = try JSONDecoder.nexoDefault.decode(BusinessContextResponse.self, from: json)

        XCTAssertTrue(context.verticals.isEmpty)
        XCTAssertFalse(context.verticals.hasRestaurant)
        XCTAssertNil(context.verticals.defaultVerticalCode)
    }

    func testDetectsForeignVerticalsIfBackendLeaksThem() {
        let context = BusinessVerticalContext(
            activeVerticals: [
                BusinessActiveVertical(
                    code: "restaurant",
                    displayName: "Restaurante v1",
                    packageVersion: "1.0.0",
                    status: "ACTIVE"
                ),
                BusinessActiveVertical(
                    code: "gym",
                    displayName: "Gym v1",
                    packageVersion: "1.0.0",
                    status: "ACTIVE"
                )
            ]
        )

        XCTAssertEqual(context.foreignVerticalCodes, ["gym"])
    }
}
