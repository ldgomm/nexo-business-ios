//
//  Payments16CEncodingTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class Payments16CEncodingTests: XCTestCase {
    func testRegisterPaymentEncodesBackendShape() throws {
        let request = RegisterPaymentRequest(
            saleId: "sale_1",
            cashSessionId: "cash_1",
            method: "cash",
            amount: "24.00",
            reference: nil,
            note: "Pago efectivo",
            markRemainingAsReceivable: false
        )

        let data = try JSONEncoder.nexoDefault.encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let amount = try XCTUnwrap(object["amount"] as? [String: Any])

        XCTAssertEqual(object["saleId"] as? String, "sale_1")
        XCTAssertEqual(object["cashSessionId"] as? String, "cash_1")
        XCTAssertEqual(amount["amount"] as? String, "24.00")
        XCTAssertEqual(amount["currency"] as? String, "USD")
        XCTAssertEqual(object["notes"] as? String, "Pago efectivo")
        XCTAssertEqual(object["markRemainingAsReceivable"] as? Bool, false)
        XCTAssertNil(object["note"])
    }
}
