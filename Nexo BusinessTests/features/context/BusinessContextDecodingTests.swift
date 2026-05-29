//
//  BusinessContextDecodingTests.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class BusinessContextDecodingTests: XCTestCase {
    func testDecodesBusinessContextContract() throws {
        let json = #"""
        {
          "user": {
            "id": "usr_1",
            "displayName": "Operador",
            "email": "op@nexo.test"
          },
          "organization": {
            "id": "org_1",
            "commercialName": "Altos del Murco",
            "legalName": "Altos del Murco",
            "taxId": "9999999999999",
            "countryCode": "EC"
          },
          "branches": [
            {
              "id": "br_1",
              "name": "Matriz",
              "code": "001",
              "status": "active"
            }
          ],
          "activities": [
            {
              "id": "act_1",
              "code": "restaurant",
              "name": "Restaurante",
              "activityType": "restaurant",
              "workflowMode": "quick_sale",
              "status": "active"
            }
          ],
          "activeModules": [
            "core.sales",
            "core.cash",
            "core.documents",
            "foundation.idempotency"
          ],
          "effectivePermissions": [
            "business.sales.create"
          ],
          "revisions": {
            "catalogRevision": "cat_rev_001",
            "taxConfigurationRevision": "tax_rev_001"
          },
          "readiness": {
            "status": "ready",
            "score": 100,
            "blockers": [],
            "warnings": []
          }
        }
        """#.data(using: .utf8)!

        let context = try JSONDecoder.nexoDefault.decode(
            BusinessContextResponse.self,
            from: json
        )

        XCTAssertEqual(context.organization.commercialName, "Altos del Murco")
        XCTAssertTrue(context.activeModules.contains(.coreSales))
        XCTAssertEqual(context.readiness.status, "ready")
    }
}
