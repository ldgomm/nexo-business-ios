//
//  PaymentModelsDecodingTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class PaymentModelsDecodingTests: XCTestCase {
    func testDecodesPaymentResponseContract() throws {
        let json = #"""
        {
          "payment": {
            "id": "pay_001",
            "saleId": "sale_001",
            "status": "registered",
            "method": "cash",
            "amount": {
              "amount": "11.50",
              "currency": "USD"
            },
            "reference": null,
            "note": "Pago en caja",
            "registeredAt": "2026-05-29T10:00:00Z"
          },
          "idempotencyReplayed": false
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(
            PaymentResponse.self,
            from: json
        )

        XCTAssertEqual(response.payment.id, "pay_001")
        XCTAssertEqual(response.payment.saleId, "sale_001")
        XCTAssertEqual(response.payment.method, "cash")
        XCTAssertEqual(response.payment.amount.amount, "11.50")
        XCTAssertEqual(response.idempotencyReplayed, false)
    }
}
