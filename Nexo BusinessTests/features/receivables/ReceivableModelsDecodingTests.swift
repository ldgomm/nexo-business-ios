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
    func testDecodesCustomerSnapshotAndAvoidsGenericCustomerName() throws {
        let json = #"""
        {
          "id": "recv_002",
          "saleId": "sale_7b0b42da31",
          "customerId": "cus_001",
          "customerName": "Cliente identificado",
          "customerSnapshot": {
            "id": "cus_001",
            "name": "José Ruiz"
          },
          "status": "open",
          "amount": {
            "amount": "27.60",
            "currency": "USD"
          },
          "balance": {
            "amount": "27.60",
            "currency": "USD"
          }
        }
        """#.data(using: .utf8)!

        let receivable = try JSONDecoder.nexoDefault.decode(ReceivableRecord.self, from: json)

        XCTAssertEqual(receivable.customerSnapshot?.displayName, "José Ruiz")
        XCTAssertEqual(receivable.displayCustomerName, "José Ruiz")
        XCTAssertEqual(receivable.displaySaleReference, "SALE-7B0B42DA31")
    }


    func testFinalConsumerReceivableIsTreatedAsMissingCustomer() {
        let receivable = ReceivableRecord(
            id: "recv_final",
            saleId: "sale_final",
            customerId: "cus_final_consumer",
            customerName: "Consumidor final",
            status: "open",
            amount: MoneyAmount(amount: "10.00"),
            balance: MoneyAmount(amount: "10.00")
        )

        XCTAssertTrue(receivable.isMissingCustomer)
        XCTAssertNil(receivable.customer360Seed)
        XCTAssertEqual(receivable.displayCustomerName, "Cliente por revisar")
    }

    func testMissingCustomerNameUsesReviewCopyInsteadOfGenericIdentifiedCopy() {
        let receivable = ReceivableRecord(
            id: "recv_003",
            saleId: "sale_001",
            customerId: "cus_001",
            status: "open",
            amount: MoneyAmount(amount: "10.00"),
            balance: MoneyAmount(amount: "10.00")
        )

        XCTAssertEqual(receivable.displayCustomerName, "Cliente por revisar")
        XCTAssertFalse(receivable.hasResolvableCustomerName)
    }

}
