//
//  BusinessDocumentModelsDecodingTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class BusinessDocumentModelsDecodingTests: XCTestCase {
    func testDecodesBusinessDocumentsResponse() throws {
        let json = #"""
        {
          "documents": [
            {
              "id": "doc_1",
              "saleId": "sale_1",
              "type": "internal_ticket",
              "status": "generated",
              "number": "T-001",
              "createdAt": "2026-05-29T12:00:00Z"
            },
            {
              "id": "doc_2",
              "saleId": "sale_1",
              "type": "physical_sale_note",
              "status": "registered",
              "number": "001-001-000000123",
              "customerEmail": "cliente@nexo.test",
              "createdAt": "2026-05-29T12:05:00Z"
            }
          ]
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(
            BusinessDocumentsResponse.self,
            from: json
        )

        XCTAssertEqual(response.documents.count, 2)
        XCTAssertEqual(response.documents[0].type, "internal_ticket")
        XCTAssertEqual(response.documents[1].number, "001-001-000000123")
        XCTAssertEqual(response.documents[1].customerEmail, "cliente@nexo.test")
    }

    func testDecodesDocumentResponseWithOptionalSale() throws {
        let json = #"""
        {
          "document": {
            "id": "doc_1",
            "saleId": "sale_1",
            "type": "internal_ticket",
            "status": "generated",
            "number": "T-001"
          },
          "idempotencyReplayed": false
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(
            BusinessDocumentResponse.self,
            from: json
        )

        XCTAssertEqual(response.document.id, "doc_1")
        XCTAssertNil(response.sale)
        XCTAssertEqual(response.idempotencyReplayed, false)
    }
}
