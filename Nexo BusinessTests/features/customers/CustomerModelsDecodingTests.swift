//
//  CustomerModelsDecodingTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class CustomerModelsDecodingTests: XCTestCase {
    func testDecodesCustomerEnvelope() throws {
        let json = #"""
        {
          "customer": {
            "id": "cus_1",
            "displayName": "Cliente Demo",
            "identificationType": "ruc",
            "identificationNumber": "1799999999001",
            "email": "cliente@nexo.test",
            "phone": "0999999999",
            "address": "Quito",
            "status": "active",
            "createdAt": "2026-05-29T10:00:00Z",
            "updatedAt": "2026-05-29T10:00:00Z"
          },
          "idempotencyReplayed": false
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(CustomerResponse.self, from: json)

        XCTAssertEqual(response.customer.id, "cus_1")
        XCTAssertEqual(response.customer.displayName, "Cliente Demo")
        XCTAssertEqual(response.customer.identificationType, .ruc)
        XCTAssertEqual(response.customer.identificationNumber, "1799999999001")
        XCTAssertEqual(response.idempotencyReplayed, false)
    }

    func testDecodesSearchResponseWithItemsAlias() throws {
        let json = #"""
        {
          "items": [
            {
              "_id": "cus_1",
              "name": "María López",
              "idType": "cedula",
              "taxId": "1712345678",
              "email": "maria@nexo.test"
            }
          ]
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(CustomersSearchResponse.self, from: json)

        XCTAssertEqual(response.customers.count, 1)
        XCTAssertEqual(response.customers[0].id, "cus_1")
        XCTAssertEqual(response.customers[0].displayName, "María López")
        XCTAssertEqual(response.customers[0].identificationType, .cedula)
        XCTAssertEqual(response.customers[0].identificationNumber, "1712345678")
    }
}
