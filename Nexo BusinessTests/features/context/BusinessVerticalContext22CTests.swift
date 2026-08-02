//
//  BusinessVerticalContext22CTests.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/7/26.
//

import XCTest
@testable import Nexo_Business

class BusinessVerticalContext22CTests: XCTestCase {

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
