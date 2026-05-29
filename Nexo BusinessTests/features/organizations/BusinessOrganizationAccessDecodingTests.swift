//
//  BusinessOrganizationAccessDecodingTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class BusinessOrganizationAccessDecodingTests: XCTestCase {
    func testDecodesOrganizationsResponse() throws {
        let json = #"""
        {
          "organizations": [
            {
              "organizationId": "org_1",
              "commercialName": "Altos del Murco",
              "legalName": "Altos del Murco",
              "taxId": "1799999999001",
              "countryCode": "EC",
              "roleName": "Operador",
              "status": "active"
            }
          ]
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(
            BusinessOrganizationAccessResponse.self,
            from: json
        )

        XCTAssertEqual(response.organizations.count, 1)
        XCTAssertEqual(response.organizations[0].id, "org_1")
        XCTAssertEqual(response.organizations[0].commercialName, "Altos del Murco")
        XCTAssertEqual(response.organizations[0].taxId, "1799999999001")
    }

    func testDecodesFlexiblePayloadNames() throws {
        let json = #"""
        {
          "data": [
            {
              "_id": "org_2",
              "name": "Tienda Demo",
              "ruc": "0999999999001",
              "role": "Encargado"
            }
          ]
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(
            BusinessOrganizationAccessResponse.self,
            from: json
        )

        XCTAssertEqual(response.organizations[0].id, "org_2")
        XCTAssertEqual(response.organizations[0].commercialName, "Tienda Demo")
        XCTAssertEqual(response.organizations[0].taxId, "0999999999001")
        XCTAssertEqual(response.organizations[0].roleName, "Encargado")
    }
}
