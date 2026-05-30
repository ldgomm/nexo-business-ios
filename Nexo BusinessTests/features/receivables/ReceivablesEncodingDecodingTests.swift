//
//  Receivables16CEncodingDecodingTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class Receivables16CEncodingDecodingTests: XCTestCase {
    func testCreateReceivableEncodesDueAtAndReasonOnly() throws {
        let request = CreateReceivableRequest(
            saleId: "sale_1",
            customerId: "cus_1",
            amount: "24.00",
            dueDate: nil,
            note: "Cliente dejó saldo"
        )

        let data = try JSONEncoder.nexoDefault.encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["saleId"] as? String, "sale_1")
        XCTAssertEqual(object["reason"] as? String, "Cliente dejó saldo")
        XCTAssertNil(object["customerId"])
        XCTAssertNil(object["amount"])
        XCTAssertNil(object["note"])
    }

    func testCollectReceivableEncodesMoneyObjectAndNotes() throws {
        let request = CollectReceivableRequest(
            receivableId: "recv_1",
            cashSessionId: "cash_1",
            method: "cash",
            amount: "10.00",
            reference: nil,
            note: "Abono"
        )

        let data = try JSONEncoder.nexoDefault.encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let amount = try XCTUnwrap(object["amount"] as? [String: Any])

        XCTAssertEqual(object["receivableId"] as? String, "recv_1")
        XCTAssertEqual(object["cashSessionId"] as? String, "cash_1")
        XCTAssertEqual(amount["amount"] as? String, "10.00")
        XCTAssertEqual(object["notes"] as? String, "Abono")
    }

    func testDecodesReceivablesListFromBackend16B() throws {
        let json = #"""
        {
          "receivables": [
            {
              "id": "recv_1",
              "saleId": "sale_1",
              "branchId": "br_1",
              "customerId": "cus_1",
              "customerName": "Cliente prueba",
              "status": "open",
              "originalAmount": { "amount": "24.00", "currency": "USD" },
              "paidAmount": { "amount": "0.00", "currency": "USD" },
              "remainingAmount": { "amount": "24.00", "currency": "USD" },
              "dueAt": "2026-06-05T00:00:00Z",
              "createdAt": "2026-05-29T00:00:00Z"
            }
          ],
          "total": 1,
          "hasMore": false,
          "nextCursor": null
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(ReceivablesListResponse.self, from: json)
        let receivable = try XCTUnwrap(response.receivables.first)
        let dueDate = try XCTUnwrap(receivable.dueDate)

        XCTAssertEqual(receivable.remainingAmount?.amount, "24.00")
        XCTAssertEqual(
            dueDate.timeIntervalSince1970,
            1_780_617_600,
            accuracy: 1
        )
    }
}
