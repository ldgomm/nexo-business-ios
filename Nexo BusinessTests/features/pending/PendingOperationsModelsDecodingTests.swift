//
//  PendingOperationsModelsDecodingTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class PendingOperationsModelsDecodingTests: XCTestCase {
    func testDecodesPendingSalesFromItemsEnvelope() throws {
        let json = #"""
        {
          "items": [
            {
              "id": "sale_1",
              "organizationId": "org_1",
              "branchId": "br_1",
              "activityId": "act_1",
              "status": "confirmed",
              "paymentStatus": "unpaid",
              "documentStatus": "not_required",
              "totals": {
                "subtotalWithoutTaxes": { "amount": "10.00", "currency": "USD" },
                "discountTotal": { "amount": "0.00", "currency": "USD" },
                "taxTotal": { "amount": "1.50", "currency": "USD" },
                "grandTotal": { "amount": "11.50", "currency": "USD" }
              }
            }
          ],
          "total": 1
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(
            PendingSalesResponse.self,
            from: json
        )

        XCTAssertEqual(response.sales.count, 1)
        XCTAssertEqual(response.sales[0].id, "sale_1")
        XCTAssertEqual(response.total, 1)
    }

    func testDecodesPendingReceivablesFromReceivablesEnvelope() throws {
        let json = #"""
        {
          "receivables": [
            {
              "id": "recv_1",
              "saleId": "sale_1",
              "customerId": "cus_1",
              "status": "pending",
              "amount": { "amount": "20.00", "currency": "USD" },
              "balance": { "amount": "20.00", "currency": "USD" }
            }
          ]
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(
            PendingReceivablesResponse.self,
            from: json
        )

        XCTAssertEqual(response.receivables.count, 1)
        XCTAssertEqual(response.receivables[0].id, "recv_1")
        XCTAssertEqual(response.receivables[0].balance?.amount, "20.00")
    }

    func testDecodesPendingDocumentsFromResultsEnvelope() throws {
        let json = #"""
        {
          "results": [
            {
              "id": "doc_1",
              "saleId": "sale_1",
              "type": "electronic_invoice",
              "status": "rejected",
              "number": "001-001-000000001"
            }
          ]
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(
            PendingDocumentsResponse.self,
            from: json
        )

        XCTAssertEqual(response.documents.count, 1)
        XCTAssertEqual(response.documents[0].type, "electronic_invoice")
        XCTAssertEqual(response.documents[0].status, "rejected")
    }
}
