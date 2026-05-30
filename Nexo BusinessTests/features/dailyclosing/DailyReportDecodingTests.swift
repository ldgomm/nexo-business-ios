//
//  DailyReport16CDecodingTests.swift
//  Nexo BusinessTests
//

import XCTest
@testable import Nexo_Business

final class DailyReport16CDecodingTests: XCTestCase {
    func testDecodesBackendDailyReportEnvelope() throws {
        let json = #"""
        {
          "report": {
            "businessDate": "2026-05-29",
            "branchId": "br_1",
            "salesCount": 5,
            "cancelledSalesCount": 0,
            "salesTotal": { "amount": "120.00", "currency": "USD" },
            "paymentsTotal": { "amount": "120.00", "currency": "USD" },
            "cashExpectedAmount": { "amount": "140.00", "currency": "USD" },
            "receivablesOpenAmount": { "amount": "0.00", "currency": "USD" },
            "pendingSalesCount": 0,
            "pendingDocumentsCount": 0,
            "openReceivablesCount": 0,
            "cashSessionId": "cash_1",
            "cashSessionStatus": "open",
            "generatedAt": "2026-05-29T23:00:00Z"
          }
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(BusinessDailyReportResponse.self, from: json)

        XCTAssertEqual(response.report.salesTotal?.amount, "120.00")
        XCTAssertEqual(response.report.cashStatus, "open")
        XCTAssertEqual(response.report.openReceivablesCount, 0)
    }
}
