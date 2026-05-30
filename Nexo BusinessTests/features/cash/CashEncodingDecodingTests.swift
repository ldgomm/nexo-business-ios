//
//  Cash16CEncodingDecodingTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class Cash16CEncodingDecodingTests: XCTestCase {
    func testOpenCashSessionEncodesBackendMoneyObject() throws {
        let request = OpenCashSessionRequest(
            branchId: "br_1",
            openingAmount: "20.00",
            note: "Apertura smoke"
        )

        let data = try JSONEncoder.nexoDefault.encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let balance = try XCTUnwrap(object["openingBalance"] as? [String: Any])

        XCTAssertEqual(object["branchId"] as? String, "br_1")
        XCTAssertEqual(balance["amount"] as? String, "20.00")
        XCTAssertEqual(balance["currency"] as? String, "USD")
        XCTAssertEqual(object["notes"] as? String, "Apertura smoke")
        XCTAssertNil(object["openingAmount"])
        XCTAssertNil(object["note"])
    }

    func testCurrentCashSessionDecodesCashSessionEnvelope() throws {
        let json = #"""
        {
          "cashSession": {
            "id": "cash_1",
            "branchId": "br_1",
            "status": "open",
            "openingBalance": { "amount": "20.00", "currency": "USD" },
            "openedAt": "2026-05-29T10:00:00Z"
          }
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(CashCurrentSessionResponse.self, from: json)

        XCTAssertEqual(response.session?.id, "cash_1")
        XCTAssertEqual(response.session?.openingAmount?.amount, "20.00")
    }

    func testCloseCashEncodesReasonAndCountedCashAmount() throws {
        let request = CloseCashSessionRequest(
            countedAmount: "44.00",
            note: "Sin novedades"
        )

        let data = try JSONEncoder.nexoDefault.encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let amount = try XCTUnwrap(object["countedCashAmount"] as? [String: Any])

        XCTAssertEqual(amount["amount"] as? String, "44.00")
        XCTAssertEqual(object["reason"] as? String, "Sin novedades")
        XCTAssertEqual(object["notes"] as? String, "Sin novedades")
    }
}
