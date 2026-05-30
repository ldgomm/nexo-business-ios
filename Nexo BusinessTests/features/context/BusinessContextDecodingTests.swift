//
//  BusinessContext16CDecodingTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class BusinessContext16CDecodingTests: XCTestCase {
    func testDecodesBackendRealContextShapeAndComputesCompatibilityFields() throws {
        let json = #"""
        {
          "user": { "id": "usr_1", "displayName": "Operador", "email": "op@nexo.test" },
          "organization": {
            "id": "org_1",
            "commercialName": "Altos del Murco",
            "legalName": "Altos del Murco",
            "taxId": "1790000000001",
            "countryCode": "EC"
          },
          "branches": [
            { "id": "br_1", "name": "Matriz", "code": "001", "status": "active" }
          ],
          "activeBranchId": "br_1",
          "activities": [
            {
              "id": "act_1",
              "activityType": "restaurant",
              "workflowMode": "quick_sale",
              "status": "active",
              "requiresScheduling": false
            }
          ],
          "activeModules": ["core.sales", "core.cash"],
          "effectivePermissions": ["sales.create", "cash.open"],
          "catalogRevision": "catrev_1",
          "taxConfigurationRevision": "taxrev_1",
          "moduleReadiness": {
            "core.sales": { "status": "ready", "blockers": [], "warnings": [] }
          },
          "environment": "staging",
          "serverTime": "2026-05-29T00:00:00Z"
        }
        """#.data(using: .utf8)!

        let context = try JSONDecoder.nexoDefault.decode(BusinessContextResponse.self, from: json)

        XCTAssertEqual(context.activeBranchId, "br_1")
        XCTAssertEqual(context.revisions.catalogRevision, "catrev_1")
        XCTAssertEqual(context.revisions.taxConfigurationRevision, "taxrev_1")
        XCTAssertEqual(context.readiness.status, "ready")
        XCTAssertEqual(context.activities.first?.code, "restaurant")
        XCTAssertEqual(context.activities.first?.name, "Restaurant")
    }
}
