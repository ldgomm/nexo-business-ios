//
//  ReceivableModelsDecodingTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class ReceivableModelsDecodingTests: XCTestCase {
    func testDecodesReceivableResponseContract() throws {
        let json = #"""
        {
          "receivable": {
            "id": "recv_001",
            "saleId": "sale_001",
            "customerId": "cus_001",
            "status": "pending",
            "amount": {
              "amount": "11.50",
              "currency": "USD"
            },
            "balance": {
              "amount": "11.50",
              "currency": "USD"
            },
            "dueDate": "2026-06-05T00:00:00Z",
            "createdAt": "2026-05-29T10:00:00Z"
          },
          "idempotencyReplayed": false
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(
            ReceivableResponse.self,
            from: json
        )

        XCTAssertEqual(response.receivable.id, "recv_001")
        XCTAssertEqual(response.receivable.customerId, "cus_001")
        XCTAssertEqual(response.receivable.status, "pending")
        XCTAssertEqual(response.receivable.amount.amount, "11.50")
        XCTAssertEqual(response.receivable.balance?.amount, "11.50")
    }
}
