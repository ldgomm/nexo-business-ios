//
//  Customers16CDecodingEncodingTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class Customers16CDecodingEncodingTests: XCTestCase {
    func testDecodesBackendIdentificationField() throws {
        let json = #"""
        {
          "customers": [
            {
              "id": "cus_1",
              "displayName": "Cliente prueba",
              "identificationType": "cedula",
              "identification": "0102030405",
              "email": null,
              "phone": null,
              "status": "active"
            }
          ]
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(CustomersSearchResponse.self, from: json)

        XCTAssertEqual(response.customers.first?.identificationNumber, "0102030405")
    }

    func testCreateCustomerEncodesIdentificationForBackend() throws {
        let request = CreateCustomerRequest(
            displayName: "Cliente prueba",
            identificationType: .cedula,
            identificationNumber: "0102030405",
            notes: "Cliente smoke"
        )

        let data = try JSONEncoder.nexoDefault.encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["displayName"] as? String, "Cliente prueba")
        XCTAssertEqual(object["identification"] as? String, "0102030405")
        XCTAssertNil(object["identificationNumber"])
    }
}
