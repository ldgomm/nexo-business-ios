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
            "method": "CASH",
            "amount": {
              "amount": "11.50",
              "currency": "USD"
            },
            "reference": null,
            "note": "Pago en caja",
            "registeredAt": "2026-05-29T10:00:00Z"
          },
          "saleId": "sale_001",
          "salePaymentStatus": "PAID",
          "salePaidAmount": {
            "amount": "11.50",
            "currency": "USD"
          },
          "cashSession": {
            "id": "cash_001",
            "branchId": "br_001",
            "status": "open",
            "openedAt": null,
            "closedAt": null,
            "openingBalance": {
              "amount": "20.00",
              "currency": "USD"
            }
          },
          "cashMovement": {
            "id": "cmov_001",
            "cashSessionId": "cash_001",
            "type": "manual",
            "direction": "inflow",
            "amount": {
              "amount": "11.50",
              "currency": "USD"
            }
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
        XCTAssertEqual(response.payment.method, "CASH")
        XCTAssertEqual(response.payment.amount.amount, "11.50")
        XCTAssertEqual(response.saleId, "sale_001")
        XCTAssertEqual(response.salePaymentStatus, "PAID")
        XCTAssertEqual(response.salePaidAmount?.amount, "11.50")
        XCTAssertEqual(response.cashSession?.id, "cash_001")
        XCTAssertEqual(response.cashMovement?.id, "cmov_001")
        XCTAssertEqual(response.idempotencyReplayed, false)
    }

    func testBusinessPaymentMethodEncodesUppercaseBackendContract() throws {
        XCTAssertEqual(BusinessPaymentMethod.cash.rawValue, "CASH")
        XCTAssertEqual(BusinessPaymentMethod.transfer.rawValue, "BANK_TRANSFER")
        XCTAssertEqual(BusinessPaymentMethod.card.rawValue, "CARD_MANUAL")
        XCTAssertEqual(BusinessPaymentMethod.other.rawValue, "OTHER")
    }
}
